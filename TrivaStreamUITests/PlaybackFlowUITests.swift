//
//  PlaybackFlowUITests.swift
//  TrivaStreamUITests
//

import XCTest

/// End-to-end playback flows against the bundled catalog (real SoundHelix URLs), so they need
/// network access and are skipped rather than failed when the first track can't start.
final class PlaybackFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testSeekPauseResumeAndSwitchTrack() throws {
        let slider = try startFirstTrack()

        // Seek while playing: must recover to playing, not stay stuck loading.
        slider.adjust(toNormalizedSliderPosition: 0.5)
        waitUntilEnabled(slider)
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 15), "should be playing again after the seek")
        XCTAssertGreaterThan(seconds(slider), 30, "position should be near the seek target")

        // Pause, then seek while paused: position updates and stays paused.
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5))
        let beforePausedSeek = seconds(slider)
        slider.adjust(toNormalizedSliderPosition: 0.2)
        XCTAssertTrue(waitFor { abs(self.seconds(slider) - beforePausedSeek) > 10 }, "paused seek should move the thumb")
        XCTAssertTrue(app.buttons["Play"].exists, "seeking while paused must not resume playback")

        // Resume: progress advances again from the new position.
        app.buttons["Play"].tap()
        let resumedFrom = seconds(slider)
        XCTAssertTrue(waitFor { self.seconds(slider) > resumedFrom + 2 }, "progress should advance after resuming")

        // Switch track: scrubber resets and disables while the new item loads.
        app.buttons["Library"].tap()
        XCTAssertTrue(app.cells.element(boundBy: 1).waitForExistence(timeout: 5))
        app.cells.element(boundBy: 1).tap()
        waitUntilEnabled(slider)
        XCTAssertLessThan(seconds(slider), 15, "new track should start near the beginning")
    }

    func testPlaybackContinuesInBackground() throws {
        let slider = try startFirstTrack()
        let before = seconds(slider)

        XCUIDevice.shared.press(.home)
        sleep(6)
        app.activate()

        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 10), "still playing after returning to the app")
        XCTAssertTrue(waitFor { self.seconds(slider) > before + 4 }, "playback should have kept advancing while backgrounded")
    }

    // MARK: - Helpers

    private func startFirstTrack() throws -> XCUIElement {
        guard app.cells.firstMatch.waitForExistence(timeout: 15) else {
            throw XCTSkip("Catalog did not load")
        }
        app.cells.firstMatch.tap()
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 10))
        let ready = NSPredicate(format: "isEnabled == true")
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: ready, object: slider)], timeout: 40)
        try XCTSkipUnless(result == .completed, "Track did not start (network unavailable?)")
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 10))
        return slider
    }

    private func waitUntilEnabled(_ slider: XCUIElement, timeout: TimeInterval = 20) {
        let ready = NSPredicate(format: "isEnabled == true")
        wait(for: [XCTNSPredicateExpectation(predicate: ready, object: slider)], timeout: timeout)
    }

    /// The slider exposes its raw value in seconds while enabled and a percentage while disabled.
    private func seconds(_ slider: XCUIElement) -> Double {
        let text = "\(slider.value ?? "0")".replacingOccurrences(of: "%", with: "")
        return Double(text) ?? 0
    }

    private func waitFor(timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            usleep(200_000)
        }
        return condition()
    }
}
