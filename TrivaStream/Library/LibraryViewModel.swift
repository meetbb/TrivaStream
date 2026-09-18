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

    private let repository: ContentRepository

    init(repository: ContentRepository) {
        self.repository = repository
    }

    func loadCatalog() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await repository.fetchCatalog()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
