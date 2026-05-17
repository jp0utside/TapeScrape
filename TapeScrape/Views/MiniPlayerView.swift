import SwiftUI

struct MiniPlayerView: View {
    @Environment(PlaybackCoordinator.self) private var playback

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(trackTitle)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                playback.togglePlayPause()
            } label: {
                Image(systemName: playback.state.isPlaying ? "pause.fill" : "play.fill")
                    .imageScale(.large)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var trackTitle: String {
        playback.currentTrack?.title ?? playback.currentTrack?.filename ?? ""
    }

    private var statusLabel: String {
        switch playback.state {
        case .loading:      "Loading…"
        case .playing:      "Playing"
        case .paused:       "Paused"
        case .failed:       "Playback failed"
        case .idle:         ""
        }
    }
}
