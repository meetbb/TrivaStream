//
//  PlaybackUIState.swift
//  TrivaStream
//
//  Created by Meet Brahmbhatt on 18/09/26.
//

import AudioStreamKit

/// What a screen actually needs to render, derived from AudioStreamKit's `PlaybackState`.
/// Keeping this mapping in one place means every consumer of playback state — `PlayerView`
/// today, any second consumer added later per ADR-002/ADR-004 — shares one translation
/// instead of each re-implementing the same `switch`.
enum PlaybackUIState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case error(message: String)

    init(_ state: PlaybackState) {
        switch state {
        case .idle, .ended:
            self = .idle
        case .loading, .buffering, .stalled:
            self = .loading
        case .playing:
            self = .playing
        case .paused:
            self = .paused
        case .failed(let error):
            self = .error(message: error.errorDescription ?? "Playback failed.")
        }
    }
}
