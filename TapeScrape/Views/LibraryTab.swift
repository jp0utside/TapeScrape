import SwiftUI

struct LibraryTab: View {
    @Environment(\.libraryRepository) private var library
    @State private var favorites: [ConcertSnapshot] = []
    @State private var playlists: [Tag] = []

    private var isEmpty: Bool { favorites.isEmpty && playlists.isEmpty }

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
        playlists = await library.playlistTags()
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
