//
//  LibraryView.swift
//  TrivaStream
//
//  Created by Meet Brahmbhatt on 18/09/26.
//

import SwiftUI

struct LibraryView: View {
    @Bindable var libraryViewModel: LibraryViewModel
    let playerViewModel: PlayerViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Library")
                .searchable(text: $libraryViewModel.searchText, prompt: "Search Freesound")
                .task { await libraryViewModel.loadCatalog() }
                .task(id: libraryViewModel.searchText) { await libraryViewModel.search() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if libraryViewModel.isLoading {
            ProgressView()
        } else if let errorMessage = libraryViewModel.errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
        } else {
            List(libraryViewModel.items) { item in
                NavigationLink(item.title) {
                    PlayerView(viewModel: playerViewModel)
                        .task { await playerViewModel.select(item) }
                }
            }
        }
    }
}
