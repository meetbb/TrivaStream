//
//  TrivaStreamApp.swift
//  TrivaStream
//
//  Created by Meet Brahmbhatt on 17/09/26.
//

import AudioStreamKit
import SwiftUI

/// Composition root. Creates the app's single `AudioPlayer` instance (ADR-002) and single
/// `ContentRepository` (ADR-003) exactly once, and hands them down — nothing below this
/// constructs its own copy of either.
@main
struct TrivaStreamApp: App {
    private let repository: ContentRepository = FreesoundContentRepository(apiKey: Self.freesoundAPIKey)
    private let playerViewModel = PlayerViewModel(player: AudioPlayer())
    private let libraryViewModel: LibraryViewModel

    /// Injected via `Secrets.xcconfig` (gitignored) → `INFOPLIST_KEY_FreesoundAPIKey`, so the
    /// real key never lands in source control.
    private static var freesoundAPIKey: String {
        Bundle.main.object(forInfoDictionaryKey: "FreesoundAPIKey") as? String ?? ""
    }

    init() {
        libraryViewModel = LibraryViewModel(repository: repository)
    }

    var body: some Scene {
        WindowGroup {
            LibraryView(
                libraryViewModel: libraryViewModel,
                playerViewModel: playerViewModel
            )
        }
    }
}
