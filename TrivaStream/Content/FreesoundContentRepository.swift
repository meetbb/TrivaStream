//
//  FreesoundContentRepository.swift
//  TrivaStream
//
//  Created by Meet Brahmbhatt on 23/09/26.
//

import Foundation
import os

/// TrivaStream's sole content source: Freesound.org's text search API. `fetchCatalog()` and
/// `search(query:)` both hit the same endpoint — an empty query returns Freesound's own default
/// ordering, which is what `fetchCatalog()` uses for the Library screen's launch content.
struct FreesoundContentRepository: ContentRepository {
    private static let logger = Logger(subsystem: "com.sunbreathingcode.TrivaStream", category: "ContentRepository")
    private static let searchURL = URL(string: "https://freesound.org/apiv2/search/text/")!

    private let apiKey: String
    private let urlSession: URLSession

    init(apiKey: String, urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.urlSession = urlSession
    }

    /// Default Library content: an empty query returns all Freesound sounds in the API's own
    /// relevance order. No custom `sort` yet — that's a separate, later decision.
    func fetchCatalog() async throws -> [MediaCatalogItem] {
        try await performSearch(query: "")
    }

    func search(query: String) async throws -> [MediaCatalogItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return try await performSearch(query: trimmed)
    }

    private func performSearch(query: String) async throws -> [MediaCatalogItem] {
        var components = URLComponents(url: Self.searchURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            // Explicit field list: Freesound's default response omits `previews` (needed to
            // play a result) and `images` (needed for the grid thumbnail).
            URLQueryItem(name: "fields", value: "id,name,username,previews,images"),
        ]

        var request = URLRequest(url: components.url!)
        // Token auth in the header, not the URL, so the key doesn't end up in logs or history.
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            Self.logger.error("Freesound search failed with non-2xx response")
            throw FreesoundError.requestFailed
        }

        return Self.parse(data)
    }

    /// Exposed for direct unit testing against synthetic JSON, without a live network call.
    static func parse(_ data: Data) -> [MediaCatalogItem] {
        guard let decoded = try? JSONDecoder().decode(SearchResponse.self, from: data) else {
            logger.error("Failed to decode Freesound search response")
            return []
        }

        var seenURLs = Set<URL>()
        var items: [MediaCatalogItem] = []

        for result in decoded.results {
            // Prefer the higher-quality preview; fall back to the low-quality one if that's
            // all Freesound returned for this sound.
            guard
                let previewURLString = result.previews.previewHqMp3 ?? result.previews.previewLqMp3,
                let previewURL = URL(string: previewURLString),
                seenURLs.insert(previewURL).inserted
            else {
                continue
            }

            let thumbnailURL = result.images?.waveformM.flatMap(URL.init(string:))
            // Freesound's own sound id, not a fresh UUID: it's stable across repeated
            // fetches of the same sound, so SwiftUI's diffing can recognize an unchanged
            // reload instead of tearing down and rebuilding every grid cell.
            items.append(MediaCatalogItem(id: String(result.id), title: result.name, artist: result.username, url: previewURL, thumbnailURL: thumbnailURL))
        }

        return items
    }
}

private struct SearchResponse: Decodable {
    let results: [SearchResult]
}

private struct SearchResult: Decodable {
    let id: Int
    let name: String
    let username: String
    let previews: Previews
    let images: Images?

    struct Previews: Decodable {
        let previewHqMp3: String?
        let previewLqMp3: String?

        enum CodingKeys: String, CodingKey {
            case previewHqMp3 = "preview-hq-mp3"
            case previewLqMp3 = "preview-lq-mp3"
        }
    }

    struct Images: Decodable {
        let waveformM: String?

        enum CodingKeys: String, CodingKey {
            case waveformM = "waveform_m"
        }
    }
}

enum FreesoundError: LocalizedError {
    case requestFailed

    var errorDescription: String? {
        "Freesound search failed. Please try again."
    }
}
