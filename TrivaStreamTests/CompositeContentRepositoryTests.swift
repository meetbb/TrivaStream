//
//  CompositeContentRepositoryTests.swift
//  TrivaStreamTests
//
//  Created by Meet Brahmbhatt on 23/09/26.
//

import Foundation
import XCTest
@testable import TrivaStream

final class CompositeContentRepositoryTests: XCTestCase {
    func testFetchCatalogDelegatesToCatalogSource() async throws {
        let catalogItem = MediaCatalogItem(title: "Bundled", artist: "Artist", url: URL(string: "https://example.com/bundled.mp3")!)
        let repository = CompositeContentRepository(
            catalogSource: StubRepository(catalogItems: [catalogItem]),
            searchSource: StubRepository()
        )

        let items = try await repository.fetchCatalog()

        XCTAssertEqual(items, [catalogItem])
    }

    func testSearchDelegatesToSearchSource() async throws {
        let searchItem = MediaCatalogItem(title: "Found", artist: "Artist", url: URL(string: "https://example.com/found.mp3")!)
        let repository = CompositeContentRepository(
            catalogSource: StubRepository(),
            searchSource: StubRepository(searchItems: [searchItem])
        )

        let items = try await repository.search(query: "anything")

        XCTAssertEqual(items, [searchItem])
    }
}

private struct StubRepository: ContentRepository {
    var catalogItems: [MediaCatalogItem] = []
    var searchItems: [MediaCatalogItem] = []

    func fetchCatalog() async throws -> [MediaCatalogItem] {
        catalogItems
    }

    func search(query: String) async throws -> [MediaCatalogItem] {
        searchItems
    }
}
