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
