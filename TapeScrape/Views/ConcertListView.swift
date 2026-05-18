import SwiftUI

struct ConcertListView: View {
    let artist: ArtistMatch

    @State private var concerts: [ConcertListItem] = []
    @State private var isLoading = false
    @State private var currentPage = 1
    @State private var totalConcerts = 0

    private var hasMore: Bool { concerts.count < totalConcerts }

    var body: some View {
        Group {
            if isLoading && concerts.isEmpty {
                ProgressView("Loading concerts…")
            } else if concerts.isEmpty {
                ContentUnavailableView(
                    "No concerts found",
                    systemImage: "music.note.list",
                    description: Text("No recordings found for \(artist.displayArtist).")
                )
            } else {
                List {
                    ForEach(concerts, id: \.id) { item in
                        NavigationLink(value: item) {
                            ConcertRow(item: item)
                        }
                    }
                    if hasMore {
                        Button(isLoading ? "Loading…" : "Load more") {
                            Task { await loadPage(currentPage + 1) }
                        }
                        .disabled(isLoading)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .navigationTitle(artist.displayArtist)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: ConcertListItem.self) { item in
            ConcertDetailLoaderView(concertId: item.id, title: item.date)
        }
        .task { await loadPage(1) }
    }

    private func loadPage(_ page: Int) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await CatalogClient.shared.getConcerts(artist: artist.canonicalArtist, page: page)
            totalConcerts = response.total
            currentPage = response.page
            if page == 1 {
                concerts = response.concerts
            } else {
                concerts.append(contentsOf: response.concerts)
            }
        } catch {
            // Leave existing concerts in place; empty state shows on first load failure.
        }
    }
}

private struct ConcertRow: View {
    let item: ConcertListItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.date)
                .font(.headline)
            if let venue = item.displayVenue {
                Text(venue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let location = item.location {
                Text(location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(item.recordingCount) recording\(item.recordingCount == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

struct ConcertDetailLoaderView: View {
    let concertId: String
    let title: String

    @State private var concert: ConcertDetailResponse?
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading…")
            } else if let concert {
                ConcertDetailView(concert: concert)
            } else {
                ContentUnavailableView(
                    "Concert not found",
                    systemImage: "music.note",
                    description: Text("Could not load this concert.")
                )
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard concert == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        concert = try? await CatalogClient.shared.getConcertDetail(id: concertId)
    }
}
