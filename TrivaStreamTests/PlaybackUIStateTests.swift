//
//  PlaybackUIStateTests.swift
//  TrivaStreamTests
//
//  Created by Meet Brahmbhatt on 18/09/26.
//

import AudioStreamKit
import XCTest
@testable import TrivaStream

final class PlaybackUIStateTests: XCTestCase {
    func testPlayingMapsToPlaying() {
        XCTAssertEqual(PlaybackUIState(.playing), .playing)
    }

    func testLoadingBufferingAndStalledAllMapToLoading() {
        XCTAssertEqual(PlaybackUIState(.loading), .loading)
        XCTAssertEqual(PlaybackUIState(.buffering), .loading)
        XCTAssertEqual(PlaybackUIState(.stalled), .loading)
    }

    func testIdleAndEndedBothMapToIdle() {
        XCTAssertEqual(PlaybackUIState(.idle), .idle)
        XCTAssertEqual(PlaybackUIState(.ended), .idle)
    }

    func testFailedMapsToErrorWithDisplayMessage() {
        let state = PlaybackUIState(.failed(.unsupportedFormat))
        XCTAssertEqual(state, .error(message: "This media format isn't supported."))
    }
}
