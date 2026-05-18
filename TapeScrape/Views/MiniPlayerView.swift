import SwiftUI

struct MiniPlayerView: View {
    @Binding var showNowPlaying: Bool
    @Environment(PlaybackCoordinator.self) private var playback

    var body: some View {
        Button {
            showNowPlaying = true
        } label: {
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
                    Image(systemName: playPauseImage)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var trackTitle: String {
        playback.currentTrack?.title ?? playback.currentTrack?.filename ?? ""
    }

    private var playPauseImage: String {
        playback.state.isPlaying ? "pause.fill" : "play.fill"
    }

    private var statusLabel: String {
        switch playback.state {
        case .loading:  "Loading…"
        case .stalled:  "Buffering…"
        case .playing:  "Playing"
        case .paused:   "Paused"
        case .failed:   "Playback failed — tap to retry"
        case .idle:     ""
        }
    }
}
