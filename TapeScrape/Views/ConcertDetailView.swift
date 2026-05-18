import SwiftUI

// Captures the tracks + concert metadata needed to add items to a playlist.
fileprivate struct PendingPlaylistAdd: Identifiable {
    let id = UUID()
    let tracks: [TrackResponse]
    let recordingIdentifier: String
    let concertID: String
    let artist: String
    let date: String
    let venue: String?
}

struct ConcertDetailView: View {
    let concert: ConcertDetailResponse

    @Environment(PlaybackCoordinator.self) private var playback
    @Environment(\.libraryRepository) private var library
    @State private var isFavorited = false
    @State private var pendingPlaylistAdd: PendingPlaylistAdd?

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
                let context = ConcertContext(
                    concertID: concert.id,
                    recordingIdentifier: recording.identifier,
                    artist: concert.artist,
                    date: concert.date,
                    venue: concert.venue
                )
                Section {
                    ForEach(recording.tracks, id: \.index) { track in
                        let idx = recording.tracks.firstIndex(where: { $0.index == track.index }) ?? 0
                        TrackRow(
                            track: track,
                            isCurrentTrack: playback.currentTrack?.filename == track.filename
                        ) {
                            playback.play(recording.tracks, startingAt: idx, concert: context)
                        }
                        .contextMenu {
                            Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") {
                                playback.playNext([track], concert: context)
                            }
                            Button("Add to Queue", systemImage: "text.badge.plus") {
                                playback.addToEnd([track], concert: context)
                            }
                            Divider()
                            Button("Add to Playlist...", systemImage: "music.note.list") {
                                pendingPlaylistAdd = PendingPlaylistAdd(
                                    tracks: [track],
                                    recordingIdentifier: recording.identifier,
                                    concertID: concert.id,
                                    artist: concert.artist,
                                    date: concert.date,
                                    venue: concert.venue
                                )
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(recording.source ?? recording.sourceQuality)
                        Spacer()
                        Menu {
                            Button("Play Recording Next", systemImage: "text.line.first.and.arrowtriangle.forward") {
                                playback.playNext(recording.tracks, concert: context)
                            }
                            Button("Add Recording to Queue", systemImage: "text.badge.plus") {
                                playback.addToEnd(recording.tracks, concert: context)
                            }
                            Divider()
                            Button("Add Recording to Playlist...", systemImage: "music.note.list") {
                                pendingPlaylistAdd = PendingPlaylistAdd(
                                    tracks: recording.tracks,
                                    recordingIdentifier: recording.identifier,
                                    concertID: concert.id,
                                    artist: concert.artist,
                                    date: concert.date,
                                    venue: concert.venue
                                )
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .navigationTitle(concert.date)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await toggleFavorite() }
                } label: {
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorited ? .red : .primary)
                }
            }
        }
        .task {
            isFavorited = await library.isFavorited(concert.id)
        }
        .sheet(item: $pendingPlaylistAdd) { pending in
            AddToPlaylistSheet(pending: pending)
                .environment(\.libraryRepository, library)
        }
    }

    private func toggleFavorite() async {
        let snapshot = ConcertSnapshot(
            id: concert.id,
            artist: concert.artist,
            date: concert.date,
            venue: concert.venue,
            location: concert.location
        )
        let newValue = !isFavorited
        isFavorited = newValue   // optimistic update
        try? await library.setFavorite(snapshot, isFavorite: newValue)
    }
}

// MARK: - AddToPlaylistSheet

fileprivate struct AddToPlaylistSheet: View {
    let pending: PendingPlaylistAdd

    @Environment(\.libraryRepository) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var playlists: [Tag] = []
    @State private var showNewPlaylistAlert = false
    @State private var newPlaylistName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("New Playlist...") {
                        newPlaylistName = ""
                        showNewPlaylistAlert = true
                    }
                }
                if !playlists.isEmpty {
                    Section("Playlists") {
                        ForEach(playlists) { playlist in
                            Button(playlist.name) {
                                Task {
                                    try? await library.addToPlaylist(id: playlist.id, items: makeItems())
                                    dismiss()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { playlists = await library.playlistTags() }
            .alert("New Playlist", isPresented: $showNewPlaylistAlert) {
                TextField("Name", text: $newPlaylistName)
                Button("Create") {
                    let name = newPlaylistName
                    Task {
                        guard !name.isEmpty else { return }
                        let tag = try? await library.createPlaylist(name: name)
                        if let tag { try? await library.addToPlaylist(id: tag.id, items: makeItems()) }
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func makeItems() -> [PlaylistItem] {
        pending.tracks.enumerated().map { idx, track in
            PlaylistItem(
                id: UUID(),
                recordingIdentifier: pending.recordingIdentifier,
                trackFilename: track.filename,
                streamURL: track.streamUrl,
                trackTitle: track.title,
                trackDuration: track.duration,
                trackIndex: track.index,
                sortOrder: idx,
                concertID: pending.concertID,
                artist: pending.artist,
                date: pending.date,
                venue: pending.venue
            )
        }
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
