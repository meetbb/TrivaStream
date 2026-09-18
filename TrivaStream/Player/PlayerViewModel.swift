//
//  PlayerViewModel.swift
//  TrivaStream
//
//  Created by Meet Brahmbhatt on 18/09/26.
//

import AudioStreamKit
import Observation

/// Owns the app's single `AudioPlayer` instance (ADR-002) and translates its state into
/// `PlaybackUIState` for `PlayerView`. Holds `AudioPlayer` directly, with no wrapper
/// protocol (ADR-001) — AudioStreamKit's own design already intends it to be used this way.
@MainActor
@Observable
final class PlayerViewModel {
    private(set) var uiState: PlaybackUIState = .idle
    private(set) var currentItem: MediaCatalogItem?

    private let player: AudioPlayer

    init(player: AudioPlayer) {
        self.player = player

        // `states` is nonisolated on the actor, so this loop can start immediately without
        // waiting on the actor; it just keeps running for the lifetime of this view model.
        Task { [weak self, player] in
            for await state in player.states {
                self?.uiState = PlaybackUIState(state)
            }
        }
    }

    func select(_ item: MediaCatalogItem) async {
        currentItem = item
        await player.load(item.mediaItem)
        await player.play()
    }

    func togglePlayPause() async {
        if uiState == .playing {
            await player.pause()
        } else {
            await player.play()
        }
    }
}
