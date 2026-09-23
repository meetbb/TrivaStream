//
//  CompositeContentRepository.swift
//  TrivaStream
//
//  Created by Meet Brahmbhatt on 23/09/26.
//

import Foundation

/// Routes `ContentRepository`'s two operations to different sources: the bundled catalog
/// for `fetchCatalog()`, Freesound for `search(query:)`. Keeps ADR-003's single repository
/// seam intact for callers — `LibraryViewModel` still only knows about one `ContentRepository`
/// — while each underlying source stays a plain, independently testable implementation of it.
struct CompositeContentRepository: ContentRepository {
    private let catalogSource: ContentRepository
    private let searchSource: ContentRepository

    init(catalogSource: ContentRepository, searchSource: ContentRepository) {
        self.catalogSource = catalogSource
        self.searchSource = searchSource
    }

    func fetchCatalog() async throws -> [MediaCatalogItem] {
        try await catalogSource.fetchCatalog()
    }

    func search(query: String) async throws -> [MediaCatalogItem] {
        try await searchSource.search(query: query)
    }
}
