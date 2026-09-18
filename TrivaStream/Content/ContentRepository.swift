//
//  ContentRepository.swift
//  TrivaStream
//
//  Created by Meet Brahmbhatt on 18/09/26.
//

import Foundation

/// Single point of access for TrivaStream's content catalog (ADR-003). Every screen that
/// needs catalog data goes through this rather than loading it independently, so a future
/// change in where the catalog comes from (bundled data today, possibly a remote API later)
/// only requires a new conformance here.
protocol ContentRepository: Sendable {
    func fetchCatalog() async throws -> [MediaCatalogItem]
}

/// Placeholder catalog source. Stands in for a bundled-JSON or remote-API implementation —
/// swapping either in later is a new `ContentRepository` conformance, not a change to any
/// screen that consumes this protocol.
struct StaticContentRepository: ContentRepository {
    func fetchCatalog() async throws -> [MediaCatalogItem] {
        [
            MediaCatalogItem(
                title: "Sample Track",
                artist: "TrivaStream",
                url: URL(string: "https://example.com/sample.mp3")!
            )
        ]
    }
}
