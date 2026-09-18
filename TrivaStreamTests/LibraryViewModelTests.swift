//
//  LibraryViewModelTests.swift
//  TrivaStreamTests
//
//  Created by Meet Brahmbhatt on 18/09/26.
//

import Foundation
import XCTest
@testable import TrivaStream

@MainActor
final class LibraryViewModelTests: XCTestCase {
    func testLoadCatalogPopulatesItemsFromRepository() async {
        let expected = [
            MediaCatalogItem(title: "Track", artist: "Artist", url: URL(string: "https://example.com/a.mp3")!)
        ]
        let viewModel = LibraryViewModel(repository: StubContentRepository(items: expected))

        await viewModel.loadCatalog()

        XCTAssertEqual(viewModel.items, expected)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadCatalogSurfacesRepositoryFailure() async {
        let viewModel = LibraryViewModel(repository: StubContentRepository(error: URLError(.notConnectedToInternet)))

        await viewModel.loadCatalog()

        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }
}

private struct StubContentRepository: ContentRepository {
    var items: [MediaCatalogItem] = []
    var error: Error?

    func fetchCatalog() async throws -> [MediaCatalogItem] {
        if let error {
            throw error
        }
        return items
    }
}
