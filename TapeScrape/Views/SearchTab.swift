import SwiftUI

struct SearchTab: View {
    @State private var query = ""
    @State private var results: [ArtistMatch] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    ProgressView("Searching…")
                } else if results.isEmpty && !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(results, id: \.canonicalArtist) { artist in
                        NavigationLink(value: artist) {
                            ArtistRow(artist: artist)
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
        }
        .searchable(text: $query, prompt: "Artist name")
        .onChange(of: query) { _, newQuery in
            searchTask?.cancel()
            guard !newQuery.isEmpty else {
                results = []
                return
            }
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await search(query: newQuery)
            }
        }
    }

    private func search(query: String) async {
        isSearching = true
        defer { isSearching = false }
        do {
            let response = try await CatalogClient.shared.searchArtists(query: query)
            results = response.matches
        } catch {
            results = []
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
