import SwiftUI

private enum SearchScope: String, CaseIterable {
    case artists = "Artists"
    case tracks = "Tracks"
}

struct SearchTab: View {
    @State private var query = ""
    @State private var scope: SearchScope = .artists
    @State private var artistResults: [ArtistMatch] = []
    @State private var trackResults: [TrackMatch] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private var isEmpty: Bool {
        scope == .artists ? artistResults.isEmpty : trackResults.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    ProgressView("Searching…")
                } else if isEmpty && !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else if scope == .artists {
                    List(artistResults, id: \.canonicalArtist) { artist in
                        NavigationLink(value: artist) {
                            ArtistRow(artist: artist)
                        }
                    }
                } else {
                    List(trackResults) { track in
                        NavigationLink(value: track.concertId) {
                            TrackRow(track: track)
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: ArtistMatch.self) { artist in
                ConcertListView(artist: artist)
            }
            .navigationDestination(for: ConcertListItem.self) { item in
                ConcertDetailLoaderView(concertId: item.id, title: item.date)
            }
            .navigationDestination(for: String.self) { concertId in
                ConcertDetailLoaderView(concertId: concertId, title: concertId)
            }
        }
        .searchable(text: $query, prompt: scope == .artists ? "Artist name" : "Track title")
        .searchScopes($scope) {
            ForEach(SearchScope.allCases, id: \.self) { s in
                Text(s.rawValue).tag(s)
            }
        }
        .onChange(of: query) { _, newQuery in
            triggerSearch(query: newQuery)
        }
        .onChange(of: scope) { _, _ in
            triggerSearch(query: query)
        }
    }

    private func triggerSearch(query: String) {
        searchTask?.cancel()
        artistResults = []
        trackResults = []
        guard !query.isEmpty else { return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await search(query: query)
        }
    }

    private func search(query: String) async {
        isSearching = true
        defer { isSearching = false }
        do {
            switch scope {
            case .artists:
                let response = try await CatalogClient.shared.searchArtists(query: query)
                artistResults = response.matches
            case .tracks:
                let response = try await CatalogClient.shared.searchTracks(query: query)
                trackResults = response.results
            }
        } catch {
            artistResults = []
            trackResults = []
        }
    }
}

private struct ArtistRow: View {
    let artist: ArtistMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(artist.displayArtist)
                .font(.headline)
            Text("\(artist.recordingCount) recording\(artist.recordingCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct TrackRow: View {
    let track: TrackMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(track.title ?? track.filename)
                .font(.headline)
            Text("\(track.artist) · \(track.date)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let venue = track.venue {
                Text(venue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
