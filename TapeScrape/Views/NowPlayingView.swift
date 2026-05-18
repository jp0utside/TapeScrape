import SwiftUI

struct NowPlayingView: View {
    @Environment(PlaybackCoordinator.self) private var playback
    @Environment(\.dismiss) private var dismiss

    @State private var scrubPosition: Double = 0
    @State private var isScrubbing = false

    private var displayPosition: Double {
        guard playback.duration > 0 else { return 0 }
        return isScrubbing ? scrubPosition : playback.elapsed / playback.duration
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                artworkPlaceholder
                    .padding(.horizontal, 32)
                    .padding(.top, 16)

                trackInfo
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                scrubber
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                controls
                    .padding(.top, 20)

                Divider()
                    .padding(.top, 24)

                trackList
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var artworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(artColor)
                .aspectRatio(1, contentMode: .fit)
            if playback.state.isStalled || playback.state.isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .shadow(color: artColor.opacity(0.4), radius: 16, x: 0, y: 8)
    }

    private var artColor: Color {
        guard let track = playback.currentTrack else { return .gray }
        let seed = track.filename.unicodeScalars.reduce(0) { $0 ^ $1.value }
        let hue = Double(seed % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.55)
    }

    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(playback.currentTrack?.title ?? playback.currentTrack?.filename ?? "–")
                .font(.title3.bold())
                .lineLimit(2)
            if case .failed(let err) = playback.state {
                Text(err.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if playback.state.isStalled {
                Text("Buffering…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { displayPosition },
                    set: { newValue in
                        isScrubbing = true
                        scrubPosition = newValue
                    }
                ),
                in: 0...1
            ) { editing in
                if !editing {
                    playback.seek(to: scrubPosition)
                    isScrubbing = false
                }
            }

            HStack {
                Text(formatTime(playback.elapsed))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Text("-" + formatTime(max(0, playback.duration - playback.elapsed)))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 44) {
            Button {
                playback.skipBack()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
            }

            Button {
                if case .failed = playback.state {
                    playback.retry()
                } else {
                    playback.togglePlayPause()
                }
            } label: {
                Image(systemName: playButtonImage)
                    .font(.system(size: 52))
            }

            Button {
                playback.skipForward()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
            }
        }
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
    }

    private var playButtonImage: String {
        switch playback.state {
        case .playing:          "pause.circle.fill"
        case .loading, .stalled: "pause.circle.fill"
        case .failed:           "arrow.clockwise.circle.fill"
        default:                "play.circle.fill"
        }
    }

    private var trackList: some View {
        List(Array(playback.queue.enumerated()), id: \.offset) { idx, track in
            Button {
                playback.play(playback.queue, startingAt: idx)
            } label: {
                HStack(spacing: 10) {
                    if idx == playback.currentIndex {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 20)
                    } else {
                        Text("\(idx + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title ?? track.filename)
                            .foregroundStyle(idx == playback.currentIndex ? Color.accentColor : .primary)
                        if let dur = track.durationSeconds {
                            Text(formatTime(dur))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}
