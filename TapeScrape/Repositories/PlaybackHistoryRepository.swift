import Foundation
import SwiftUI

struct PlayRecord {
    let identifier: String
    let trackFile: String
    let playedAt: Date
}

struct ConcertContext: Sendable {
    let concertID: String
    let recordingIdentifier: String
    let artist: String
    let date: String
    let venue: String?
}

struct RecentConcert: Identifiable, Hashable, Sendable {
    var id: String { concertID }
    let concertID: String
    let artist: String
    let date: String
    let venue: String?
    let lastPlayedAt: Date
}

struct EngagedArtist: Identifiable, Hashable, Sendable {
    var id: String { canonicalArtist }
    let canonicalArtist: String
    let displayArtist: String
    let lastPlayedAt: Date
    let playCount: Int
}

protocol PlaybackHistoryRepository: Sendable {
    func recordPlay(identifier: String, trackFile: String, at: Date,
                    context: ConcertContext) async throws
    func recentPlays(limit: Int) async -> [PlayRecord]
    func recentConcerts(limit: Int) async -> [RecentConcert]
    func distinctArtists(limit: Int) async -> [EngagedArtist]
}

private struct PlaybackHistoryRepositoryKey: EnvironmentKey {
    static let defaultValue: any PlaybackHistoryRepository = InMemoryPlaybackHistoryRepository()
}

extension EnvironmentValues {
    var playbackHistoryRepository: any PlaybackHistoryRepository {
        get { self[PlaybackHistoryRepositoryKey.self] }
        set { self[PlaybackHistoryRepositoryKey.self] = newValue }
    }
}

actor InMemoryPlaybackHistoryRepository: PlaybackHistoryRepository {
    private struct Entry {
        let record: PlayRecord
        let context: ConcertContext
    }

    private var entries: [Entry] = []

    func recordPlay(identifier: String, trackFile: String, at date: Date,
                    context: ConcertContext) async throws {
        entries.append(Entry(
            record: PlayRecord(identifier: identifier, trackFile: trackFile, playedAt: date),
            context: context
        ))
    }

    func recentPlays(limit: Int) async -> [PlayRecord] {
        Array(entries.map { $0.record }.sorted { $0.playedAt > $1.playedAt }.prefix(limit))
    }

    func recentConcerts(limit: Int) async -> [RecentConcert] {
        var latestByID: [String: (context: ConcertContext, date: Date)] = [:]
        for entry in entries {
            let cid = entry.context.concertID
            if let existing = latestByID[cid] {
                if entry.record.playedAt > existing.date {
                    latestByID[cid] = (entry.context, entry.record.playedAt)
                }
            } else {
                latestByID[cid] = (entry.context, entry.record.playedAt)
            }
        }
        return Array(
            latestByID.values
                .sorted { $0.date > $1.date }
                .prefix(limit)
                .map { entry in
                    RecentConcert(
                        concertID: entry.context.concertID,
                        artist: entry.context.artist,
                        date: entry.context.date,
                        venue: entry.context.venue,
                        lastPlayedAt: entry.date
                    )
                }
        )
    }

    func distinctArtists(limit: Int) async -> [EngagedArtist] {
        var byArtist: [String: (displayArtist: String, lastPlayedAt: Date, playCount: Int)] = [:]
        for entry in entries {
            let key = entry.context.artist.lowercased()
            if let existing = byArtist[key] {
                byArtist[key] = (
                    existing.displayArtist,
                    max(existing.lastPlayedAt, entry.record.playedAt),
                    existing.playCount + 1
                )
            } else {
                byArtist[key] = (entry.context.artist, entry.record.playedAt, 1)
            }
        }
        return Array(
            byArtist
                .sorted { $0.value.lastPlayedAt > $1.value.lastPlayedAt }
                .prefix(limit)
                .map { key, value in
                    EngagedArtist(
                        canonicalArtist: key,
                        displayArtist: value.displayArtist,
                        lastPlayedAt: value.lastPlayedAt,
                        playCount: value.playCount
                    )
                }
        )
    }
}
