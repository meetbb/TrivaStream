//
//  PlayerView.swift
//  TrivaStream
//
//  Created by Meet Brahmbhatt on 18/09/26.
//

import SwiftUI

struct PlayerView: View {
    @Bindable var viewModel: PlayerViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text(viewModel.currentItem?.title ?? "Nothing playing")
                .font(.title2)
            Text(viewModel.currentItem?.artist ?? "")
                .foregroundStyle(.secondary)
            statusView
            scrubber
            Button {
                Task { await viewModel.togglePlayPause() }
            } label: {
                Image(systemName: viewModel.uiState == .playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
            }
            .disabled(viewModel.currentItem == nil)
        }
        .padding()
        .navigationTitle("Now Playing")
        .task { await viewModel.trackProgress() }
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { viewModel.displayedTime },
                    set: { viewModel.scrub(to: $0) }
                ),
                in: 0...max(viewModel.duration ?? 1, 0.01),
                onEditingChanged: { isEditing in
                    if !isEditing {
                        Task { await viewModel.commitScrub() }
                    }
                }
            )
            .disabled(!viewModel.isSeekable)

            HStack {
                Text(Self.format(viewModel.displayedTime))
                Spacer()
                Text("-" + Self.format(max((viewModel.duration ?? 0) - viewModel.displayedTime, 0)))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private static func format(_ time: TimeInterval) -> String {
        let seconds = Int(time.rounded(.down))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.uiState {
        case .loading:
            ProgressView()
        case .error(let message):
            Text(message)
                .foregroundStyle(.red)
        case .idle, .playing, .paused:
            EmptyView()
        }
    }
}
