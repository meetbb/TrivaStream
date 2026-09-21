//
//  PlayerViewModel.swift
//  TrivaStream
//
//  Created by Meet Brahmbhatt on 18/09/26.
//

import AudioStreamKit
import Foundation
import Observation

/// Owns the app's single `AudioPlayer` instance (ADR-002) and translates its state into
/// `PlaybackUIState` for `PlayerView`. Holds `AudioPlayer` directly, with no wrapper
/// protocol (ADR-001) — AudioStreamKit's own design already intends it to be used this way.
@MainActor
@Observable
final class PlayerViewModel {
    private(set) var uiState: PlaybackUIState = .idle
    private(set) var currentItem: MediaCatalogItem?
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval?

    /// Where the user's thumb is while dragging, and until the seek it triggered has settled.
    /// `nil` when the slider should just follow `currentTime`.
    private(set) var scrubPosition: TimeInterval?

    /// What the slider and time labels should show.
    var displayedTime: TimeInterval { scrubPosition ?? currentTime }

    /// The scrubber is only usable once the engine can honor a seek: it ignores seeks while
    /// `.loading` and after a failure (where `duration` can still hold the last known value),
    /// and there is nothing to scrub until the duration is known.
    var isSeekable: Bool {
        guard currentItem != nil, (duration ?? 0) > 0 else { return false }
        switch uiState {
        case .idle, .playing, .paused: return true
        case .loading, .error: return false
        }
    }

    private let player: AudioPlayer
    private var seeksInFlight = 0

    /// `AudioPlayer.states` has a single consumer, so exactly one view model may observe it
    /// (ADR-002). Cancelled in `deinit`, which is nonisolated — hence the unsafe handle.
    @ObservationIgnored private nonisolated(unsafe) var observationTask: Task<Void, Never>?

    init(player: AudioPlayer) {
        self.player = player

        // `states` is nonisolated on the actor, so this loop can start immediately without
        // waiting on the actor.
        observationTask = Task { [weak self, player] in
            for await state in player.states {
                self?.apply(state)
            }
        }
    }

    deinit {
        observationTask?.cancel()
    }

    func select(_ item: MediaCatalogItem) async {
        // `PlayerView` calls this on every appearance; re-entering the screen for the item that
        // is already active must not restart it. Keyed by `url` because `id` is regenerated
        // whenever the catalog is decoded. An ended or failed item is restarted on purpose.
        if currentItem?.url == item.url {
            switch uiState {
            case .playing, .paused, .loading: return
            case .idle, .error: break
            }
        }

        currentItem = item
        currentTime = 0
        duration = nil
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

extension PlayerViewModel {
    /// Ignored unless the engine can honor a seek, so a stray call can't leave the thumb stuck.
    func scrub(to time: TimeInterval) {
        guard isSeekable else { return }
        scrubPosition = min(max(time, 0), duration ?? time)
    }

    /// Seeks to the scrubbed position. A no-op when nothing was scrubbed.
    func commitScrub() async {
        guard let target = scrubPosition else { return }
        seeksInFlight += 1
        defer { seeksInFlight -= 1 }

        await player.seek(to: target)
        // Release the thumb only after `currentTime` has caught up, or it would flash the
        // pre-seek position. A newer drag may have replaced the target meanwhile; keep that one.
        await refreshProgress()
        if scrubPosition == target {
            scrubPosition = nil
        }
    }

    /// `AudioPlayer` exposes no time stream, so progress is polled. Run this from a visible
    /// screen (`.task`): cancellation when the screen goes away is what stops the polling.
    func trackProgress() async {
        while !Task.isCancelled {
            await refreshProgress()
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    fileprivate func apply(_ state: PlaybackState) {
        uiState = PlaybackUIState(state)

        switch uiState {
        case .idle:
            currentTime = 0
            scrubPosition = nil
        case .error:
            // Nothing valid is loaded, so don't leave the last position next to the message.
            currentTime = 0
            duration = nil
            scrubPosition = nil
        case .loading:
            // A stall disables the slider mid-drag, so its release may never arrive. A seek we
            // started also passes through `.loading` and still owns the thumb.
            if seeksInFlight == 0 {
                scrubPosition = nil
            }
        case .playing, .paused:
            break
        }
    }

    private func refreshProgress() async {
        let item = currentItem
        let time = await player.currentTime
        let total = await player.duration
        // Stale if the caller went away or a different item was selected while awaiting.
        guard !Task.isCancelled, currentItem == item else { return }

        // After `.ended` the player still reports the end position, but the idle look is 0:00;
        // after a failure the values are meaningless.
        switch uiState {
        case .idle, .error:
            return
        case .loading, .playing, .paused:
            break
        }

        currentTime = time
        duration = total
    }
}
