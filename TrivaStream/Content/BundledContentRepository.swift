//
//  BundledContentRepository.swift
//  TrivaStream
//
//  Created by Meet Brahmbhatt on 19/09/26.
//

import Foundation
import os

/// Reads TrivaStream's catalog from a JSON file bundled inside the app — the "today"
/// source described in ADR-003. Each entry is decoded and validated independently, so one
/// malformed entry doesn't fail the whole catalog; entries are deduplicated by `url`, first
/// occurrence wins. Both rules were an explicit product decision, not an implementation detail.
struct BundledContentRepository: ContentRepository {
    private static let logger = Logger(subsystem: "com.sunbreathingcode.TrivaStream", category: "ContentRepository")

    private let bundle: Bundle
    private let resourceName: String

    init(bundle: Bundle = .main, resourceName: String = "catalog") {
        self.bundle = bundle
        self.resourceName = resourceName
    }

    func fetchCatalog() async throws -> [MediaCatalogItem] {
        // `async` alone doesn't move this off the caller's actor — without an explicit hop,
        // the synchronous file read + decode below would run on whatever actor called us
        // (in practice, LibraryViewModel's MainActor). Task.detached forces it onto a
        // background executor instead.
        try await Task.detached(priority: .userInitiated) {
            try self.loadAndParse()
        }.value
    }

    private func loadAndParse() throws -> [MediaCatalogItem] {
        guard let fileURL = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw CatalogError.resourceNotFound
        }
        let data = try Data(contentsOf: fileURL)
        return try Self.parse(data)
    }

    /// Exposed for direct unit testing against synthetic JSON, without needing bundle fixtures.
    static func parse(_ data: Data) throws -> [MediaCatalogItem] {
        guard let rawEntries = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw CatalogError.invalidFormat
        }

        var seenURLs = Set<URL>()
        var items: [MediaCatalogItem] = []

        for raw in rawEntries {
            // Each entry is decoded on its own so a single malformed entry (wrong type,
            // missing field) only drops that entry rather than failing the whole catalog.
            guard
                let entryData = try? JSONSerialization.data(withJSONObject: raw),
                let entry = try? JSONDecoder().decode(CatalogEntry.self, from: entryData),
                !entry.title.isEmpty,
                let itemURL = URL(string: entry.url),
                itemURL.scheme != nil
            else {
                logger.error("Skipping invalid catalog entry: \(String(describing: raw), privacy: .public)")
                continue
            }

            guard seenURLs.insert(itemURL).inserted else {
                logger.notice("Skipping duplicate catalog entry: \(itemURL.absoluteString, privacy: .public)")
                continue
            }

            items.append(MediaCatalogItem(title: entry.title, artist: entry.artist, url: itemURL))
        }

        return items
    }
}

private struct CatalogEntry: Decodable {
    let title: String
    let artist: String
    let url: String
}

enum CatalogError: LocalizedError {
    case resourceNotFound
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .resourceNotFound:
            return "The content catalog could not be found."
        case .invalidFormat:
            return "The content catalog is malformed."
        }
    }
}
