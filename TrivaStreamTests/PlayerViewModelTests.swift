//
//  PlayerViewModelTests.swift
//  TrivaStreamTests
//

import AudioStreamKit
import Foundation
import XCTest
@testable import TrivaStream

/// Drives a real `AudioPlayer` against a loopback server (ADR-001 rules out stubbing it), so
/// these tests exercise real state transitions and take real time. Positions are compared with
/// tolerances because playback keeps advancing while a test observes it.
@MainActor
final class PlayerViewModelTests: XCTestCase {
    private var server: LoopbackMediaServer!
    private var player: AudioPlayer!
    private var viewModel: PlayerViewModel!
    private var tracking: Task<Void, Never>?

    override func setUp() async throws {
        server = LoopbackMediaServer()
        try await server.start()
        await server.setWAV(duration: 30, at: "/long.wav")
        await server.setWAV(duration: 30, at: "/other.wav")
        await server.setWAV(duration: 2, at: "/short.wav")
        player = AudioPlayer()
        viewModel = PlayerViewModel(player: player)
    }

    override func tearDown() async throws {
        tracking?.cancel()
        tracking = nil
        await player.stop()
        await server.stop()
        viewModel = nil
        player = nil
        server = nil
    }

    // MARK: - Initial / loading

    func testInitialStateHasNothingToScrub() {
        XCTAssertEqual(viewModel.uiState, .idle)
        XCTAssertEqual(viewModel.currentTime, 0)
        XCTAssertNil(viewModel.duration)
        XCTAssertFalse(viewModel.isSeekable)
        XCTAssertNil(viewModel.scrubPosition)
    }

    func testScrubIsIgnoredWhenNothingCanBeSeeked() {
        viewModel.scrub(to: 5)

        XCTAssertNil(viewModel.scrubPosition, "a stray scrub must not leave the thumb parked")
    }

    func testPlaybackBecomesSeekableOnceDurationIsKnown() async throws {
        try await startPlaying("/long.wav")

        let duration = try XCTUnwrap(viewModel.duration)
        XCTAssertEqual(duration, 30, accuracy: 0.5)
        XCTAssertTrue(viewModel.isSeekable)
    }

    func testProgressAdvancesWhilePlaying() async throws {
        try await startPlaying("/long.wav")
        let start = viewModel.currentTime

        let advanced = await waitUntil { self.viewModel.currentTime > start + 1 }

        XCTAssertTrue(advanced, "polling should move currentTime forward while playing")
    }

    // MARK: - Seeking

    func testSeekWhilePlayingReturnsToPlayingAtNewPosition() async throws {
        try await startPlaying("/long.wav")

        await seek(to: 15)

        let recovered = await waitUntil { self.viewModel.uiState == .playing && self.viewModel.currentTime >= 15 }
        XCTAssertTrue(recovered, "state must not stay stuck in .loading after a seek")
        XCTAssertLessThan(viewModel.currentTime, 20)
    }

    func testSeekWhilePausedUpdatesTimeAndStaysPaused() async throws {
        try await startPlaying("/long.wav")
        await viewModel.togglePlayPause()
        let paused = await waitUntil { self.viewModel.uiState == .paused }
        XCTAssertTrue(paused)

        await seek(to: 20)

        let updated = await waitUntil { abs(self.viewModel.currentTime - 20) < 1 }
        XCTAssertTrue(updated)
        XCTAssertEqual(viewModel.uiState, .paused)
    }

    func testNothingIsPolledWhileNoScreenIsTracking() async throws {
        try await startPlaying("/long.wav", track: false)

        try await Task.sleep(for: .milliseconds(1500))

        XCTAssertEqual(viewModel.currentTime, 0, "progress must only be read while a screen tracks it")
        XCTAssertNil(viewModel.duration)
    }

    func testCancellingTheTrackerStopsProgressUpdates() async throws {
        try await startPlaying("/long.wav")
        tracking?.cancel()
        try await Task.sleep(for: .milliseconds(700))
        let frozen = viewModel.currentTime

        try await Task.sleep(for: .milliseconds(1500))

        XCTAssertEqual(viewModel.currentTime, frozen, accuracy: 0.001, "audio keeps playing, the UI clock must not")
        XCTAssertEqual(viewModel.uiState, .playing)
    }

    func testScrubberStaysUsableAfterPlaybackEndsAndSeekLandsPaused() async throws {
        try await startPlaying("/short.wav")
        let ended = await waitUntil(timeout: 15) { self.viewModel.uiState == .idle }
        XCTAssertTrue(ended, "a 2s track should end")
        try await Task.sleep(for: .milliseconds(1200)) // longer than one polling tick
        XCTAssertEqual(viewModel.currentTime, 0, "position resets to the idle look")
        XCTAssertTrue(viewModel.isSeekable, "scrubber stays visible and usable after .ended")

        await seek(to: 1)

        let paused = await waitUntil { self.viewModel.uiState == .paused }
        XCTAssertTrue(paused)
        XCTAssertEqual(viewModel.currentTime, 1, accuracy: 0.5)
    }

    // MARK: - Selection

    func testReselectingTheActiveItemDoesNotRestartIt() async throws {
        let item = try await startPlaying("/long.wav")
        let advanced = await waitUntil { self.viewModel.currentTime > 1.5 }
        XCTAssertTrue(advanced)

        await viewModel.select(item)

        XCTAssertGreaterThan(viewModel.currentTime, 1, "re-entering the screen must not reset progress")
        XCTAssertEqual(viewModel.uiState, .playing)
    }

    func testReselectingAnEndedItemRestartsIt() async throws {
        let item = try await startPlaying("/short.wav")
        let ended = await waitUntil(timeout: 15) { self.viewModel.uiState == .idle }
        XCTAssertTrue(ended)

        await viewModel.select(item)

        let restarted = await waitUntil(timeout: 15) { self.viewModel.uiState == .playing }
        XCTAssertTrue(restarted, "a finished track should replay when selected again")
    }

    // MARK: - Reset and failure

    func testSelectingAnotherItemResetsProgress() async throws {
        try await startPlaying("/long.wav")
        _ = await waitUntil { self.viewModel.currentTime > 1 }

        let other = MediaCatalogItem(title: "Other", artist: "A", url: await server.url(for: "/other.wav"))
        await viewModel.select(other)

        XCTAssertEqual(viewModel.currentItem, other)
        XCTAssertLessThan(viewModel.currentTime, 1)
    }

    func testInvalidResourceIsNotSeekable() async throws {
        let missing = MediaCatalogItem(title: "Missing", artist: "A", url: await server.url(for: "/missing.wav"))

        await viewModel.select(missing)

        let failed = await waitUntil(timeout: 20) {
            if case .error = self.viewModel.uiState { return true }
            return false
        }
        XCTAssertTrue(failed)
        XCTAssertNil(viewModel.duration)
        XCTAssertEqual(viewModel.currentTime, 0)
        XCTAssertFalse(viewModel.isSeekable)
    }

    // MARK: - Concurrency

    func testThumbStaysWhereTheUserDraggedItWhileProgressKeepsPolling() async throws {
        try await startPlaying("/long.wav")
        let before = viewModel.currentTime

        viewModel.scrub(to: 25)
        try await Task.sleep(for: .milliseconds(1300))

        XCTAssertEqual(viewModel.displayedTime, 25, accuracy: 0.001)
        XCTAssertGreaterThan(viewModel.currentTime, before, "polling continues underneath the drag")
        await viewModel.commitScrub()
    }

    func testScrubIsClampedToTheTrackLength() async throws {
        try await startPlaying("/long.wav")

        viewModel.scrub(to: 999)
        XCTAssertEqual(try XCTUnwrap(viewModel.scrubPosition), 30, accuracy: 0.5)

        viewModel.scrub(to: -4)
        XCTAssertEqual(viewModel.scrubPosition, 0)
    }

    func testCommitReleasesTheThumbOnceTheSeekSettles() async throws {
        try await startPlaying("/long.wav")

        await seek(to: 15)

        XCTAssertNil(viewModel.scrubPosition)
        XCTAssertGreaterThanOrEqual(viewModel.currentTime, 14, "currentTime must have caught up before the thumb is released")
    }

    func testCommittingWithoutScrubbingDoesNothing() async throws {
        try await startPlaying("/long.wav")
        let before = viewModel.currentTime

        await viewModel.commitScrub()

        XCTAssertGreaterThanOrEqual(viewModel.currentTime, before)
        XCTAssertEqual(viewModel.uiState, .playing)
    }

    func testRapidRepeatedSeeksSettleOnLastTarget() async throws {
        try await startPlaying("/long.wav")

        for target in [5.0, 10, 15, 20, 12] {
            Task {
                viewModel.scrub(to: target)
                await viewModel.commitScrub()
            }
        }

        let settled = await waitUntil(timeout: 15) {
            self.viewModel.uiState == .playing && abs(self.viewModel.currentTime - 12) < 4
        }
        XCTAssertTrue(settled, "overlapping seeks must not leave the UI loading or at a stale position")
    }

    func testDroppedViewModelReleasesItsObservationLoopAndPlayer() async throws {
        // Own player: `AudioPlayer.states` has a single consumer, so it can't be shared with
        // the view model from `setUp`.
        weak var weakViewModel: PlayerViewModel?
        weak var weakPlayer: AudioPlayer?
        do {
            let localPlayer = AudioPlayer()
            let local = PlayerViewModel(player: localPlayer)
            weakPlayer = localPlayer
            weakViewModel = local
            let item = MediaCatalogItem(title: "T", artist: "A", url: await server.url(for: "/long.wav"))
            await local.select(item)
            let playing = await waitUntil(timeout: 20) { local.uiState == .playing }
            XCTAssertTrue(playing)
            await localPlayer.stop()
        }

        let released = await waitUntil(timeout: 5) { weakViewModel == nil && weakPlayer == nil }

        XCTAssertNil(weakViewModel)
        XCTAssertTrue(released, "the observation loop must not keep the view model or player alive")
    }

    // MARK: - Helpers

    @discardableResult
    private func startPlaying(_ path: String, track: Bool = true) async throws -> MediaCatalogItem {
        let item = MediaCatalogItem(title: "T", artist: "A", url: await server.url(for: path))
        if track {
            tracking = Task { await viewModel.trackProgress() }
        }
        await viewModel.select(item)
        let playing = await waitUntil(timeout: 20) {
            self.viewModel.uiState == .playing && (!track || self.viewModel.duration != nil)
        }
        XCTAssertTrue(playing, "playback did not start")
        return item
    }

    private func seek(to time: TimeInterval) async {
        viewModel.scrub(to: time)
        await viewModel.commitScrub()
    }

    private func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }
}
