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
    private let player = AudioPlayer()
    private let repository: ContentRepository = BundledContentRepository()

    var body: some Scene {
        WindowGroup {
            LibraryView(
                libraryViewModel: LibraryViewModel(repository: repository),
                playerViewModel: PlayerViewModel(player: player)
            )
        }
    }
}
