import SwiftUI

struct ConcertDetailView: View {
    let concert: ConcertResponse

    @Environment(PlaybackCoordinator.self) private var playback

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(concert.artist).font(.headline)
                    Text(concert.date).font(.subheadline)
                    if let venue = concert.venue {
                        Text(venue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let location = concert.location {
                        Text(location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            ForEach(concert.recordings, id: \.identifier) { recording in
                Section {
                    ForEach(recording.tracks, id: \.index) { track in
                        TrackRow(
                            track: track,
                            isCurrentTrack: playback.currentTrack?.filename == track.filename
                        ) {
                            playback.play(track)
                        }
                    }
                } header: {
                    Text(recording.source ?? recording.identifier)
                }
            }
        }
        .navigationTitle(concert.date)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TrackRow: View {
    let track: TrackResponse
    let isCurrentTrack: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isCurrentTrack ? "speaker.wave.2.fill" : "play.circle")
                    .foregroundStyle(isCurrentTrack ? Color.accentColor : Color.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title ?? track.filename)
                        .foregroundStyle(.primary)
                    if let dur = track.duration {
                        Text(dur)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
        }
    }
}
