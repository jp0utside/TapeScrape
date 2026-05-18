import Foundation
import Testing
@testable import TapeScrape

@Suite("PlaybackHistoryRepository")
struct PlaybackHistoryRepositoryTests {
    private func makeRepo() -> InMemoryPlaybackHistoryRepository {
        InMemoryPlaybackHistoryRepository()
    }

    private func makeContext(concertID: String = "gd1977-05-08",
                              artist: String = "Grateful Dead",
                              date: String = "1977-05-08",
                              venue: String? = "Barton Hall") -> ConcertContext {
        ConcertContext(concertID: concertID, recordingIdentifier: "gd77-05-08.sbd.nak",
                       artist: artist, date: date, venue: venue)
    }

    // MARK: - recentConcerts: single play

    @Test func singlePlayAppearsInRecentConcerts() async throws {
        let repo = makeRepo()
        let ctx = makeContext()
        try await repo.recordPlay(identifier: "gd77-05-08.sbd.nak", trackFile: "track01.flac",
                                   at: Date(), context: ctx)
        let recent = await repo.recentConcerts(limit: 10)
        #expect(recent.count == 1)
        #expect(recent[0].concertID == "gd1977-05-08")
        #expect(recent[0].artist == "Grateful Dead")
    }

    // MARK: - recentConcerts: grouping

    @Test func multiplePlaysOfSameConcertGroupToOneEntry() async throws {
        let repo = makeRepo()
        let ctx = makeContext()
        let earlier = Date(timeIntervalSinceNow: -3600)
        let later   = Date(timeIntervalSinceNow: -60)
        try await repo.recordPlay(identifier: "rec1", trackFile: "track01.flac",
                                   at: earlier, context: ctx)
        try await repo.recordPlay(identifier: "rec1", trackFile: "track02.flac",
                                   at: later, context: ctx)
        let recent = await repo.recentConcerts(limit: 10)
        #expect(recent.count == 1)
        #expect(abs(recent[0].lastPlayedAt.timeIntervalSince(later)) < 1)
    }

    // MARK: - recentConcerts: ordering

    @Test func differentConcertsOrderedByMostRecentPlay() async throws {
        let repo = makeRepo()
        let ctx1 = makeContext(concertID: "concert-a", date: "1977-05-08")
        let ctx2 = makeContext(concertID: "concert-b", date: "1980-10-31")
        let oldest = Date(timeIntervalSinceNow: -7200)
        let newest = Date(timeIntervalSinceNow: -60)
        try await repo.recordPlay(identifier: "rec-a", trackFile: "t1.flac",
                                   at: oldest, context: ctx1)
        try await repo.recordPlay(identifier: "rec-b", trackFile: "t1.flac",
                                   at: newest, context: ctx2)
        let recent = await repo.recentConcerts(limit: 10)
        #expect(recent.count == 2)
        #expect(recent[0].concertID == "concert-b")
        #expect(recent[1].concertID == "concert-a")
    }

    // MARK: - recentConcerts: limit

    @Test func limitCapsConcertCount() async throws {
        let repo = makeRepo()
        for i in 0..<5 {
            let ctx = makeContext(concertID: "concert-\(i)", date: "1977-0\(i+1)-01")
            try await repo.recordPlay(identifier: "rec\(i)", trackFile: "t.flac",
                                       at: Date(timeIntervalSinceNow: Double(-i * 100)),
                                       context: ctx)
        }
        let recent = await repo.recentConcerts(limit: 3)
        #expect(recent.count == 3)
    }

    // MARK: - distinctArtists: empty

    @Test func distinctArtistsEmptyWhenNoHistory() async {
        let repo = makeRepo()
        let artists = await repo.distinctArtists(limit: 5)
        #expect(artists.isEmpty)
    }

    // MARK: - distinctArtists: ordering

    @Test func distinctArtistsOrderedByMostRecentPlay() async throws {
        let repo = makeRepo()
        let ctxA = makeContext(concertID: "concert-a", artist: "Grateful Dead")
        let ctxB = makeContext(concertID: "concert-b", artist: "Phish")
        let older = Date(timeIntervalSinceNow: -7200)
        let newer = Date(timeIntervalSinceNow: -60)
        try await repo.recordPlay(identifier: "r1", trackFile: "t1.flac", at: older, context: ctxA)
        try await repo.recordPlay(identifier: "r2", trackFile: "t1.flac", at: newer, context: ctxB)
        let artists = await repo.distinctArtists(limit: 5)
        #expect(artists.count == 2)
        #expect(artists[0].displayArtist == "Phish")
        #expect(artists[1].displayArtist == "Grateful Dead")
    }

    // MARK: - distinctArtists: limit

    @Test func distinctArtistsRespectsLimit() async throws {
        let repo = makeRepo()
        for i in 0..<6 {
            let ctx = makeContext(concertID: "concert-\(i)", artist: "Artist\(i)")
            try await repo.recordPlay(identifier: "r\(i)", trackFile: "t.flac",
                                       at: Date(timeIntervalSinceNow: Double(-i * 100)),
                                       context: ctx)
        }
        let artists = await repo.distinctArtists(limit: 3)
        #expect(artists.count == 3)
    }

    // MARK: - distinctArtists: play count aggregation

    @Test func distinctArtistsAggregatesPlayCountAcrossTracksAndConcerts() async throws {
        let repo = makeRepo()
        let ctx1 = makeContext(concertID: "concert-a", artist: "Grateful Dead")
        let ctx2 = makeContext(concertID: "concert-b", artist: "Grateful Dead")
        try await repo.recordPlay(identifier: "r1", trackFile: "t1.flac",
                                   at: Date(timeIntervalSinceNow: -3000), context: ctx1)
        try await repo.recordPlay(identifier: "r1", trackFile: "t2.flac",
                                   at: Date(timeIntervalSinceNow: -2000), context: ctx1)
        try await repo.recordPlay(identifier: "r2", trackFile: "t1.flac",
                                   at: Date(timeIntervalSinceNow: -1000), context: ctx2)
        let artists = await repo.distinctArtists(limit: 5)
        #expect(artists.count == 1)
        #expect(artists[0].displayArtist == "Grateful Dead")
        #expect(artists[0].playCount == 3)
        #expect(artists[0].canonicalArtist == "grateful dead")
    }

    // MARK: - recentPlays

    @Test func recentPlaysReturnsMostRecentFirst() async throws {
        let repo = makeRepo()
        let ctx = makeContext()
        let t1 = Date(timeIntervalSinceNow: -3600)
        let t2 = Date(timeIntervalSinceNow: -60)
        try await repo.recordPlay(identifier: "rec1", trackFile: "a.flac", at: t1, context: ctx)
        try await repo.recordPlay(identifier: "rec1", trackFile: "b.flac", at: t2, context: ctx)
        let plays = await repo.recentPlays(limit: 10)
        #expect(plays.count == 2)
        #expect(plays[0].trackFile == "b.flac")
        #expect(plays[1].trackFile == "a.flac")
    }
}
