import SwiftUI

struct LibraryTab: View {
    @Environment(\.libraryRepository) private var library
    @Environment(\.downloadRepository) private var downloadRepo
    @Environment(DownloadManager.self) private var downloadManager
    @State private var favorites: [ConcertSnapshot] = []
    @State private var downloads: [DownloadRecord] = []
    @State private var playlists: [Tag] = []
    @State private var storageUsage: UInt64 = 0

    private var isEmpty: Bool { favorites.isEmpty && downloads.isEmpty && playlists.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if isEmpty {
                    ContentUnavailableView(
                        "Library is Empty",
                        systemImage: "music.note.house",
                        description: Text("Heart a concert to save it here, or add tracks to a playlist.")
                    )
                } else {
                    List {
                        if !favorites.isEmpty {
                            Section("Favorites") {
                                ForEach(favorites) { snapshot in
                                    NavigationLink(value: snapshot) {
                                        FavoriteRow(snapshot: snapshot)
                                    }
                                }
                            }
                        }
                        if !downloads.isEmpty {
                            Section {
                                ForEach(downloads) { record in
                                    NavigationLink(value: ConcertSnapshot(
                                        id: record.concertID,
                                        artist: record.artist,
                                        date: record.date,
                                        venue: record.venue,
                                        location: nil
                                    )) {
                                        DownloadRow(record: record)
                                    }
                                }
                                .onDelete { indexSet in
                                    let toDelete = indexSet.map { downloads[$0] }
                                    downloads.remove(atOffsets: indexSet)
                                    for record in toDelete {
                                        downloadManager.deleteDownload(identifier: record.identifier)
                                    }
                                }
                            } header: {
                                Text("Downloads")
                            } footer: {
                                if storageUsage > 0 {
                                    Text(ByteCountFormatter.string(
                                        fromByteCount: Int64(storageUsage), countStyle: .file
                                    ))
                                }
                            }
                        }
                        if !playlists.isEmpty {
                            Section("Playlists") {
                                ForEach(playlists) { tag in
                                    NavigationLink(value: tag) {
                                        Label(tag.name, systemImage: "music.note.list")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: ConcertSnapshot.self) { snapshot in
                ConcertDetailLoaderView(concertId: snapshot.id, title: snapshot.date)
            }
            .navigationDestination(for: Tag.self) { tag in
                PlaylistDetailView(playlistID: tag.id, playlistName: tag.name)
            }
            .task {
                await refresh()
            }
            .onAppear {
                Task { await refresh() }
            }
        }
    }

    private func refresh() async {
        favorites = await library.favoritedConcerts()
        downloads = await downloadRepo.completedDownloads()
        playlists = await library.playlistTags()
        storageUsage = downloadManager.storageUsage()
    }
}

private struct DownloadRow: View {
    let record: DownloadRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.date).font(.headline)
                Text(record.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let venue = record.venue {
                    Text(venue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
            Spacer()
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }
}

private struct FavoriteRow: View {
    let snapshot: ConcertSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(snapshot.date).font(.headline)
            Text(snapshot.artist)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let venue = snapshot.venue {
                Text(venue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let location = snapshot.location {
                Text(location)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
