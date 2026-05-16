import Foundation

struct PlayRecord {
    let identifier: String
    let trackFile: String
    let playedAt: Date
}

protocol PlaybackHistoryRepository {
    func recordPlay(identifier: String, trackFile: String, at: Date) async throws
    func recentPlays(limit: Int) async -> [PlayRecord]
}

actor InMemoryPlaybackHistoryRepository: PlaybackHistoryRepository {
    private var history: [PlayRecord] = []

    func recordPlay(identifier: String, trackFile: String, at date: Date) async throws {
        history.append(PlayRecord(identifier: identifier, trackFile: trackFile, playedAt: date))
    }

    func recentPlays(limit: Int) async -> [PlayRecord] {
        Array(history.sorted { $0.playedAt > $1.playedAt }.prefix(limit))
    }
}
