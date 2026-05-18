import SwiftUI

struct HomeTab: View {
    private let gratefulDead = ArtistMatch(
        canonicalArtist: "grateful dead",
        displayArtist: "Grateful Dead",
        recordingCount: 0
    )

    var body: some View {
        NavigationStack {
            List {
                NavigationLink(value: gratefulDead) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Grateful Dead")
                            .font(.headline)
                        Text("Browse concerts")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Home")
            .navigationDestination(for: ArtistMatch.self) { artist in
                ConcertListView(artist: artist)
            }
            .navigationDestination(for: ConcertListItem.self) { item in
                ConcertDetailLoaderView(concertId: item.id, title: item.date)
            }
        }
    }
}
