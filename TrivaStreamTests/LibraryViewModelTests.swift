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

    func testSearchWithBlankQueryRestoresCatalogItems() async {
        let defaultItems = [
            MediaCatalogItem(title: "Default", artist: "Artist", url: URL(string: "https://example.com/default.mp3")!)
        ]
        let searchItems = [
            MediaCatalogItem(title: "Freesound", artist: "Artist", url: URL(string: "https://example.com/found.mp3")!)
        ]
        let viewModel = LibraryViewModel(repository: StubContentRepository(items: defaultItems, searchItems: searchItems))
        await viewModel.loadCatalog()

        viewModel.searchText = ""
        await viewModel.search()

        XCTAssertEqual(viewModel.items, defaultItems)
    }

    func testSearchWithQueryReturnsRepositorySearchResults() async {
        let defaultItems = [
            MediaCatalogItem(title: "Default", artist: "Artist", url: URL(string: "https://example.com/default.mp3")!)
        ]
        let searchItems = [
            MediaCatalogItem(title: "Freesound", artist: "Artist", url: URL(string: "https://example.com/found.mp3")!)
        ]
        let viewModel = LibraryViewModel(repository: StubContentRepository(items: defaultItems, searchItems: searchItems))
        await viewModel.loadCatalog()

        viewModel.searchText = "ocean"
        await viewModel.search()

        XCTAssertEqual(viewModel.items, searchItems)
    }

    func testSearchSurfacesRepositoryFailure() async {
        let viewModel = LibraryViewModel(repository: StubContentRepository(searchError: URLError(.notConnectedToInternet)))

        viewModel.searchText = "ocean"
        await viewModel.search()

        XCTAssertNotNil(viewModel.errorMessage)
    }
}

private struct StubContentRepository: ContentRepository {
    var items: [MediaCatalogItem] = []
    var error: Error?
    var searchItems: [MediaCatalogItem] = []
    var searchError: Error?

    func fetchCatalog() async throws -> [MediaCatalogItem] {
        if let error {
            throw error
        }
        return items
    }

    func search(query: String) async throws -> [MediaCatalogItem] {
        if let searchError {
            throw searchError
        }
        return searchItems
    }
}
