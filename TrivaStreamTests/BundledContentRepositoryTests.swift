//
//  BundledContentRepositoryTests.swift
//  TrivaStreamTests
//
//  Created by Meet Brahmbhatt on 19/09/26.
//

import Foundation
import XCTest
@testable import TrivaStream

final class BundledContentRepositoryTests: XCTestCase {
    func testParseReturnsAllValidEntries() throws {
        let json = """
        [
            {"title": "Track A", "artist": "Artist A", "url": "https://example.com/a.mp3"},
            {"title": "Track B", "artist": "Artist B", "url": "https://example.com/b.mp3"}
        ]
        """.data(using: .utf8)!

        let items = try BundledContentRepository.parse(json)

        XCTAssertEqual(items.map(\.title), ["Track A", "Track B"])
        XCTAssertEqual(items.map(\.artist), ["Artist A", "Artist B"])
    }

    func testParseSkipsInvalidEntryButKeepsRest() throws {
        let json = """
        [
            {"title": "Good", "artist": "Artist", "url": "https://example.com/good.mp3"},
            {"title": "", "artist": "Artist", "url": "https://example.com/empty-title.mp3"},
            {"title": "Bad URL", "artist": "Artist", "url": "not a url"},
            {"title": "Missing Field", "artist": "Artist"},
            {"title": "Also Good", "artist": "Artist", "url": "https://example.com/also-good.mp3"}
        ]
        """.data(using: .utf8)!

        let items = try BundledContentRepository.parse(json)

        XCTAssertEqual(items.map(\.title), ["Good", "Also Good"])
    }

    func testParseDropsDuplicateURLsKeepingFirstOccurrence() throws {
        let json = """
        [
            {"title": "First", "artist": "Artist", "url": "https://example.com/dup.mp3"},
            {"title": "Second", "artist": "Artist", "url": "https://example.com/dup.mp3"}
        ]
        """.data(using: .utf8)!

        let items = try BundledContentRepository.parse(json)

        XCTAssertEqual(items.map(\.title), ["First"])
        XCTAssertEqual(items.first?.url, URL(string: "https://example.com/dup.mp3"))
    }

    func testParseReturnsEmptyListForEmptyCatalog() throws {
        let json = "[]".data(using: .utf8)!

        let items = try BundledContentRepository.parse(json)

        XCTAssertTrue(items.isEmpty)
    }

    func testParseThrowsForNonArrayTopLevelJSON() {
        let json = "{}".data(using: .utf8)!

        XCTAssertThrowsError(try BundledContentRepository.parse(json)) { error in
            XCTAssertTrue(error is CatalogError)
        }
    }

    func testFetchCatalogThrowsWhenResourceMissing() async {
        let repository = BundledContentRepository(bundle: Bundle(for: Self.self), resourceName: "does-not-exist")

        do {
            _ = try await repository.fetchCatalog()
            XCTFail("Expected CatalogError.resourceNotFound")
        } catch {
            XCTAssertTrue(error is CatalogError)
        }
    }
}
