//
//  LoopbackMediaServer.swift
//  TrivaStreamTests
//

import Foundation
import Network

/// Minimal loopback HTTP server so tests can drive a real `AudioPlayer` (ADR-001: no stub)
/// against deterministic media without depending on the network. Serves `GET`/`HEAD` with
/// `Range` support, which is what AudioStreamKit's `MediaSource` issues; unknown paths get 404.
actor LoopbackMediaServer {
    private var listener: NWListener?
    private var resources: [String: Data] = [:]
    private(set) var port: UInt16 = 0

    func start() async throws {
        let listener = try NWListener(using: .tcp, on: .any)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .main)
            Task { await self?.handle(connection) }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready: continuation.resume()
                case .failed(let error): continuation.resume(throwing: error)
                default: break
                }
            }
            listener.start(queue: .main)
        }
        guard let bound = listener.port else { throw URLError(.cannotConnectToHost) }
        port = bound.rawValue
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    func setWAV(duration: TimeInterval, at path: String) {
        resources[path] = Self.wav(duration: duration)
    }

    func url(for path: String) -> URL {
        URL(string: "http://127.0.0.1:\(port)\(path)")!
    }

    private func handle(_ connection: NWConnection) async {
        defer { connection.cancel() }
        guard let request = await readRequest(from: connection) else { return }
        guard let body = resources[request.path] else {
            await send(Self.response(status: 404, headers: [:], body: nil), on: connection)
            return
        }

        var headers = ["Accept-Ranges": "bytes", "Content-Type": "audio/wav"]
        let includeBody = request.method == "GET"

        if let header = request.headers["Range"], let range = Self.parseRange(header, total: body.count) {
            headers["Content-Range"] = "bytes \(range.lowerBound)-\(range.upperBound - 1)/\(body.count)"
            headers["Content-Length"] = "\(range.count)"
            let slice = body.subdata(in: range)
            await send(Self.response(status: 206, headers: headers, body: includeBody ? slice : nil), on: connection)
        } else {
            headers["Content-Length"] = "\(body.count)"
            await send(Self.response(status: 200, headers: headers, body: includeBody ? body : nil), on: connection)
        }
    }

    // MARK: - HTTP plumbing

    private struct Request {
        let method: String
        let path: String
        let headers: [String: String]
    }

    private func readRequest(from connection: NWConnection) async -> Request? {
        var buffer = Data()
        let terminator = Data("\r\n\r\n".utf8)
        while buffer.range(of: terminator) == nil {
            guard let chunk = await receive(connection), !chunk.isEmpty, buffer.count < 16_384 else { return nil }
            buffer.append(chunk)
        }
        let head = buffer[..<buffer.range(of: terminator)!.lowerBound]
        guard let text = String(data: head, encoding: .utf8) else { return nil }
        var lines = text.components(separatedBy: "\r\n")
        let parts = lines.removeFirst().split(separator: " ")
        guard parts.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[line[..<colon].trimmingCharacters(in: .whitespaces)] =
                line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        return Request(method: String(parts[0]), path: String(parts[1]), headers: headers)
    }

    private func receive(_ connection: NWConnection) async -> Data? {
        await withCheckedContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                continuation.resume(returning: error == nil ? data : nil)
            }
        }
    }

    private func send(_ data: Data, on connection: NWConnection) async {
        await withCheckedContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { _ in continuation.resume() })
        }
    }

    private static func response(status: Int, headers: [String: String], body: Data?) -> Data {
        let text = [200: "OK", 206: "Partial Content", 404: "Not Found"][status] ?? "Unknown"
        var head = "HTTP/1.1 \(status) \(text)\r\n"
        for (key, value) in headers { head += "\(key): \(value)\r\n" }
        if headers["Content-Length"] == nil { head += "Content-Length: 0\r\n" }
        head += "Connection: close\r\n\r\n"
        var data = Data(head.utf8)
        if let body { data.append(body) }
        return data
    }

    private static func parseRange(_ header: String, total: Int) -> Range<Int>? {
        guard header.hasPrefix("bytes=") else { return nil }
        let parts = header.dropFirst("bytes=".count).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, let lower = Int(parts[0]) else { return nil }
        let upperExclusive = Int(parts[1]).map { min($0 + 1, total) } ?? total
        return lower >= 0 && lower < upperExclusive ? lower..<upperExclusive : nil
    }

    /// Silent mono 16-bit PCM: real enough for `AVPlayerItem` to report a duration.
    private static func wav(duration: TimeInterval, sampleRate: UInt32 = 8000) -> Data {
        let dataSize = UInt32(Int(duration * Double(sampleRate)) * 2)
        var data = Data("RIFF".utf8)
        data.append(le(36 + dataSize)); data.append(Data("WAVEfmt ".utf8))
        data.append(le(UInt32(16))); data.append(le(UInt16(1))); data.append(le(UInt16(1)))
        data.append(le(sampleRate)); data.append(le(sampleRate * 2))
        data.append(le(UInt16(2))); data.append(le(UInt16(16)))
        data.append(Data("data".utf8)); data.append(le(dataSize))
        data.append(Data(repeating: 0, count: Int(dataSize)))
        return data
    }

    private static func le<T: FixedWidthInteger>(_ value: T) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }
}
