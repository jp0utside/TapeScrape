import SwiftUI

struct HomeTab: View {
    private let gratefulDead = ArtistMatch(
        canonicalArtist: "grateful dead",
        displayArtist: "Grateful Dead",
        recordingCount: 0
    )

    @Environment(\.playbackHistoryRepository) private var history
    @Environment(\.libraryRepository) private var library
    @State private var recentConcerts: [RecentConcert] = []
    @State private var onThisDayConcerts: [ConcertSnapshot] = []
    @State private var engagedArtists: [EngagedArtist] = []

    var body: some View {
        NavigationStack {
            List {
                if !recentConcerts.isEmpty {
                    Section("Recently Played") {
                        ForEach(recentConcerts) { concert in
                            NavigationLink(value: concert) {
                                RecentConcertRow(concert: concert)
                            }
                        }
                    }
                }

                if !onThisDayConcerts.isEmpty {
                    Section("On This Day") {
                        ForEach(onThisDayConcerts) { snapshot in
                            NavigationLink(value: snapshot) {
                                OnThisDayRow(snapshot: snapshot)
                            }
                        }
                    }
                }

                if !engagedArtists.isEmpty {
                    Section("Artists You Listen To") {
                        ForEach(engagedArtists) { artist in
                            NavigationLink(value: ArtistMatch(
                                canonicalArtist: artist.canonicalArtist,
                                displayArtist: artist.displayArtist,
                                recordingCount: 0
                            )) {
                                EngagedArtistRow(artist: artist)
                            }
                        }
                    }
                }

                if recentConcerts.isEmpty {
                    Section("Browse") {
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
                }
            }
            .navigationTitle("Home")
            .onAppear {
                Task {
                    recentConcerts = await history.recentConcerts(limit: 20)
                    engagedArtists = await history.distinctArtists(limit: 5)
                    let favorites = await library.favoritedConcerts()
                    let suffix = todayMonthDay
                    onThisDayConcerts = favorites.filter { $0.date.hasSuffix(suffix) }
                }
            }
            .navigationDestination(for: RecentConcert.self) { concert in
                ConcertDetailLoaderView(concertId: concert.concertID, title: concert.date)
            }
            .navigationDestination(for: ConcertSnapshot.self) { snapshot in
                ConcertDetailLoaderView(concertId: snapshot.id, title: snapshot.date)
            }
            .navigationDestination(for: ArtistMatch.self) { artist in
                ConcertListView(artist: artist)
            }
            .navigationDestination(for: ConcertListItem.self) { item in
                ConcertDetailLoaderView(concertId: item.id, title: item.date)
            }
        }
    }

    private var todayMonthDay: String {
        let cal = Calendar.current
        let now = Date()
        let month = cal.component(.month, from: now)
        let day = cal.component(.day, from: now)
        return String(format: "-%02d-%02d", month, day)
    }
}

private struct OnThisDayRow: View {
    let snapshot: ConcertSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.artist).font(.headline)
            Text(snapshot.date).font(.subheadline)
            if let venue = snapshot.venue {
                Text(venue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct EngagedArtistRow: View {
    let artist: EngagedArtist

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(artist.displayArtist).font(.headline)
            Text("\(artist.playCount) tracks played")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct RecentConcertRow: View {
    let concert: RecentConcert

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(concert.artist).font(.headline)
            Text(concert.date).font(.subheadline)
            if let venue = concert.venue {
                Text(venue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(concert.lastPlayedAt.relativeLabel)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

private extension Date {
    var relativeLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "Today" }
        if calendar.isDateInYesterday(self) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}
