//
//  LibraryViewModel.swift
//  TrivaStream
//
//  Created by Meet Brahmbhatt on 18/09/26.
//

import Foundation
import Observation

/// Loads TrivaStream's catalog through the single `ContentRepository` seam (ADR-003).
@MainActor
@Observable
final class LibraryViewModel {
    private(set) var items: [MediaCatalogItem] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var searchText = ""

    private let repository: ContentRepository
    private var catalogItems: [MediaCatalogItem] = []

    init(repository: ContentRepository) {
        self.repository = repository
    }

    func loadCatalog() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            catalogItems = try await repository.fetchCatalog()
            items = catalogItems
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Debounced against rapid typing: the view re-runs this in a `.task(id: searchText)`,
    /// which cancels the in-flight call whenever `searchText` changes, so only the sleep for
    /// the latest keystroke survives long enough to fire.
    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            items = catalogItems
            errorMessage = nil
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(400))
        } catch {
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await repository.search(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
