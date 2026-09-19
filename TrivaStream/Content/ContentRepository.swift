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
