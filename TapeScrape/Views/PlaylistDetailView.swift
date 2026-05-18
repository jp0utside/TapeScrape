import SwiftUI

struct PlaylistDetailView: View {
    let playlistID: Tag.ID

    @Environment(PlaybackCoordinator.self) private var playback
    @Environment(\.libraryRepository) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var playlistName: String
    @State private var items: [PlaylistItem] = []
    @State private var showDeleteConfirmation = false
    @State private var showRenameAlert = false
    @State private var newName = ""

    init(playlistID: Tag.ID, playlistName: String) {
        self.playlistID = playlistID
        _playlistName = State(initialValue: playlistName)
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "Empty Playlist",
                    systemImage: "music.note.list",
                    description: Text("Add tracks from a concert detail screen.")
                )
            } else {
                List {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        Button {
                            playPlaylist(from: idx)
                        } label: {
                            PlaylistItemRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        Task { await deleteItems(at: offsets) }
                    }
                    .onMove { source, destination in
                        Task { await moveItem(from: source, to: destination) }
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
            }
        }
        .navigationTitle(playlistName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename", systemImage: "pencil") {
                        newName = playlistName
                        showRenameAlert = true
                    }
                    Button("Delete Playlist", systemImage: "trash", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Delete \"\(playlistName)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Playlist", role: .destructive) {
                Task {
                    try? await library.deletePlaylist(id: playlistID)
                    dismiss()
                }
            }
        }
        .alert("Rename Playlist", isPresented: $showRenameAlert) {
            TextField("Name", text: $newName)
            Button("Save") {
                let name = newName
                Task {
                    guard !name.isEmpty else { return }
                    try? await library.renamePlaylist(id: playlistID, name: name)
                    playlistName = name
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task { await loadItems() }
    }

    // MARK: - Playback

    private func playPlaylist(from startIndex: Int) {
        let tracks = items.map { item in
            TrackResponse(
                index: item.trackIndex,
                title: item.trackTitle,
                filename: item.trackFilename,
                duration: item.trackDuration,
                streamUrl: item.streamURL
            )
        }
        let startItem = items[startIndex]
        let context = startItem.concertID.map { cid in
            ConcertContext(
                concertID: cid,
                recordingIdentifier: startItem.recordingIdentifier,
                artist: startItem.artist ?? "",
                date: startItem.date ?? "",
                venue: startItem.venue
            )
        }
        playback.play(tracks, startingAt: startIndex, concert: context)
    }

    // MARK: - Mutations

    private func loadItems() async {
        items = await library.playlistItems(for: playlistID)
    }

    private func deleteItems(at offsets: IndexSet) async {
        for idx in offsets.sorted().reversed() {
            guard idx < items.count else { continue }
            try? await library.removeFromPlaylist(id: playlistID, at: items[idx].sortOrder)
        }
        await loadItems()
    }

    private func moveItem(from source: IndexSet, to destination: Int) async {
        guard let from = source.first else { return }
        try? await library.moveInPlaylist(id: playlistID, from: from, to: destination)
        await loadItems()
    }
}

// MARK: - Row

private struct PlaylistItemRow: View {
    let item: PlaylistItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.trackTitle ?? item.trackFilename)
                .lineLimit(1)
            HStack(spacing: 6) {
                if let artist = item.artist, let date = item.date {
                    Text("\(artist) · \(date)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let dur = item.trackDuration {
                    Text(dur)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 2)
    }
}
