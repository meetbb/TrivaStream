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

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 20)]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Library")
                .task { await libraryViewModel.loadCatalog() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if libraryViewModel.items.isEmpty, let errorMessage = libraryViewModel.errorMessage {
            errorView(errorMessage)
        } else if libraryViewModel.isLoading && libraryViewModel.items.isEmpty {
            ProgressView()
        } else {
            searchableGrid
        }
    }

    private var searchableGrid: some View {
        VStack(spacing: 0) {
            if let errorMessage = libraryViewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            grid
        }
        .searchable(text: $libraryViewModel.searchText, prompt: "Search Freesound")
        .task(id: libraryViewModel.searchText) { await libraryViewModel.search() }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(libraryViewModel.items) { item in
                    NavigationLink {
                        PlayerView(viewModel: playerViewModel)
                            .task { await playerViewModel.select(item) }
                    } label: {
                        LibraryGridCell(item: item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("LibraryGridCell")
                }
            }
            .padding()
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Something Went Wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        }
    }
}

private struct LibraryGridCell: View {
    let item: MediaCatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnail
                .frame(height: 100)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(item.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var thumbnail: some View {
        GeometryReader { geometry in
            thumbnailContent
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let thumbnailURL = item.thumbnailURL {
            AsyncImage(url: thumbnailURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Image(systemName: "waveform")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
    }
}
