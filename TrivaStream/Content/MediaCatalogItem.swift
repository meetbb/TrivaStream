//
//  MediaCatalogItem.swift
//  TrivaStream
//
//  Created by Meet Brahmbhatt on 18/09/26.
//

import AudioStreamKit
import Foundation

/// One playable entry in TrivaStream's catalog, as surfaced by `ContentRepository`.
///
/// Distinct from AudioStreamKit's `MediaItem`: this type carries a stable `id` for SwiftUI
/// list identity, which `MediaItem` — a framework-boundary value type — has no reason to carry.
struct MediaCatalogItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let artist: String
    let url: URL
    let artworkData: Data?

    init(id: UUID = UUID(), title: String, artist: String, url: URL, artworkData: Data? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.url = url
        self.artworkData = artworkData
    }
}

extension MediaCatalogItem {
    /// Converts to the type AudioStreamKit's `AudioPlayer` actually accepts (ADR-001).
    var mediaItem: MediaItem {
        MediaItem(url: url, title: title, artist: artist, artworkData: artworkData)
    }
}
