//
//  FreesoundContentRepositoryTests.swift
//  TrivaStreamTests
//
//  Created by Meet Brahmbhatt on 23/09/26.
//

import Foundation
import XCTest
@testable import TrivaStream

final class FreesoundContentRepositoryTests: XCTestCase {
    func testParsePrefersHighQualityPreview() {
        let json = """
        {
            "results": [
                {
                    "id": 1,
                    "name": "Rain",
                    "username": "weatheruser",
                    "previews": {
                        "preview-hq-mp3": "https://example.com/rain-hq.mp3",
                        "preview-lq-mp3": "https://example.com/rain-lq.mp3"
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let items = FreesoundContentRepository.parse(json)

        XCTAssertEqual(items.map(\.title), ["Rain"])
        XCTAssertEqual(items.first?.url, URL(string: "https://example.com/rain-hq.mp3"))
    }

    func testParseFallsBackToLowQualityPreviewWhenHighQualityMissing() {
        let json = """
        {
            "results": [
                {
                    "id": 2,
                    "name": "Thunder",
                    "username": "weatheruser",
                    "previews": {
                        "preview-lq-mp3": "https://example.com/thunder-lq.mp3"
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let items = FreesoundContentRepository.parse(json)

        XCTAssertEqual(items.first?.url, URL(string: "https://example.com/thunder-lq.mp3"))
    }

    func testParseSkipsResultWithNoUsablePreview() {
        let json = """
        {
            "results": [
                {"id": 3, "name": "Silent", "username": "user", "previews": {}}
            ]
        }
        """.data(using: .utf8)!

        let items = FreesoundContentRepository.parse(json)

        XCTAssertTrue(items.isEmpty)
    }

    func testParseDropsDuplicatePreviewURLs() {
        let json = """
        {
            "results": [
                {"id": 4, "name": "First", "username": "user", "previews": {"preview-hq-mp3": "https://example.com/dup.mp3"}},
                {"id": 5, "name": "Second", "username": "user", "previews": {"preview-hq-mp3": "https://example.com/dup.mp3"}}
            ]
        }
        """.data(using: .utf8)!

        let items = FreesoundContentRepository.parse(json)

        XCTAssertEqual(items.map(\.title), ["First"])
    }

    func testParseReturnsEmptyListForMalformedJSON() {
        let json = "not json".data(using: .utf8)!

        XCTAssertTrue(FreesoundContentRepository.parse(json).isEmpty)
    }

    func testParseDecodesWaveformThumbnail() {
        let json = """
        {
            "results": [
                {
                    "id": 6,
                    "name": "Rain",
                    "username": "weatheruser",
                    "previews": {"preview-hq-mp3": "https://example.com/rain-hq.mp3"},
                    "images": {"waveform_m": "https://example.com/rain-waveform.png"}
                }
            ]
        }
        """.data(using: .utf8)!

        let items = FreesoundContentRepository.parse(json)

        XCTAssertEqual(items.first?.thumbnailURL, URL(string: "https://example.com/rain-waveform.png"))
    }

    func testParseLeavesThumbnailNilWhenImagesMissing() {
        let json = """
        {
            "results": [
                {
                    "id": 7,
                    "name": "Rain",
                    "username": "weatheruser",
                    "previews": {"preview-hq-mp3": "https://example.com/rain-hq.mp3"}
                }
            ]
        }
        """.data(using: .utf8)!

        let items = FreesoundContentRepository.parse(json)

        XCTAssertNil(items.first?.thumbnailURL)
    }

    /// The fix for the grid-reload bug: `id` must come from Freesound's own stable sound id,
    /// not a fresh random UUID, so an unchanged reload doesn't look like new rows to SwiftUI.
    func testParseUsesFreesoundSoundIDAsStableItemID() {
        let json = """
        {
            "results": [
                {"id": 12345, "name": "Rain", "username": "weatheruser", "previews": {"preview-hq-mp3": "https://example.com/rain-hq.mp3"}}
            ]
        }
        """.data(using: .utf8)!

        let items = FreesoundContentRepository.parse(json)

        XCTAssertEqual(items.first?.id, "12345")
    }

    func testFetchCatalogSendsEmptyQuery() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let responseJSON = """
        {"results": [{"id": 8, "name": "Ocean", "username": "user", "previews": {"preview-hq-mp3": "https://example.com/ocean.mp3"}}]}
        """.data(using: .utf8)!

        StubURLProtocol.stub = { request in
            let queryItems = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertTrue(queryItems.contains(URLQueryItem(name: "query", value: "")))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseJSON)
        }

        let repository = FreesoundContentRepository(apiKey: "test-key", urlSession: session)
        let items = try await repository.fetchCatalog()

        XCTAssertEqual(items.map(\.title), ["Ocean"])
    }

    func testFetchCatalogThrowsOnNonSuccessResponse() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)

        StubURLProtocol.stub = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let repository = FreesoundContentRepository(apiKey: "test-key", urlSession: session)

        do {
            _ = try await repository.fetchCatalog()
            XCTFail("Expected FreesoundError.requestFailed")
        } catch {
            XCTAssertTrue(error is FreesoundError)
        }
    }

    func testSearchWithBlankQueryReturnsEmptyListWithoutNetworkCall() async throws {
        let repository = FreesoundContentRepository(apiKey: "test-key", urlSession: .shared)

        let items = try await repository.search(query: "   ")

        XCTAssertTrue(items.isEmpty)
    }

    func testSearchSendsTokenAuthHeaderAndDecodesResponse() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let responseJSON = """
        {"results": [{"id": 8, "name": "Ocean", "username": "user", "previews": {"preview-hq-mp3": "https://example.com/ocean.mp3"}}]}
        """.data(using: .utf8)!

        StubURLProtocol.stub = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Token test-key")
            XCTAssertEqual(request.url?.host, "freesound.org")
            let queryItems = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertTrue(queryItems.contains(URLQueryItem(name: "query", value: "ocean")))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseJSON)
        }

        let repository = FreesoundContentRepository(apiKey: "test-key", urlSession: session)
        let items = try await repository.search(query: "ocean")

        XCTAssertEqual(items.map(\.title), ["Ocean"])
    }

    func testSearchThrowsOnNonSuccessResponse() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)

        StubURLProtocol.stub = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let repository = FreesoundContentRepository(apiKey: "test-key", urlSession: session)

        do {
            _ = try await repository.search(query: "ocean")
            XCTFail("Expected FreesoundError.requestFailed")
        } catch {
            XCTAssertTrue(error is FreesoundError)
        }
    }
}

/// Minimal request-stubbing protocol so these tests never touch the network.
private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var stub: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = Self.stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data) = stub(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
