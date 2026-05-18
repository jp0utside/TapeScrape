import Foundation
import SwiftUI

enum DownloadState: Sendable, Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(String)

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }
}

struct DownloadRequest: Sendable {
    let identifier: String
    let tracks: [(filename: String, streamUrl: String)]
    let concertID: String
    let artist: String
    let date: String
    let venue: String?
}

struct DownloadRecord: Identifiable, Sendable {
    var id: String { identifier }
    let identifier: String
    let concertID: String
    let state: DownloadState
    let totalTracks: Int
    let completedTracks: Int
    let artist: String
    let date: String
    let venue: String?
}

protocol DownloadRepository: Sendable {
    func startDownload(request: DownloadRequest) async throws
    func downloadState(for identifier: String) async -> DownloadState
    func allDownloads() async -> [DownloadRecord]
    func completedDownloads() async -> [DownloadRecord]
    func tracksForRecording(identifier: String) async -> [(filename: String, localPath: String)]
    func markTrackComplete(identifier: String, filename: String,
                           localPath: String) async
    func markTrackFailed(identifier: String, filename: String,
                         error: String) async
    func markRecordingComplete(identifier: String) async
    func deleteDownload(identifier: String) async throws
    func isTrackDownloaded(identifier: String, filename: String) async -> Bool
    func failedTracks(for identifier: String) async -> [(filename: String, streamUrl: String)]
    func findTrackByStreamURL(_ url: String) async -> (identifier: String, filename: String)?
    func resetTrack(identifier: String, filename: String) async
    func markRecordingFailed(identifier: String, error: String) async
}

// MARK: - InMemory stub (tests + previews)

actor InMemoryDownloadRepository: DownloadRepository {
    private struct RecordingEntry {
        var state: DownloadState
        var totalTracks: Int
        var completedTracks: Int
        let concertID: String
        let artist: String
        let date: String
        let venue: String?
        var tracks: [String: TrackEntry]
    }

    private struct TrackEntry {
        var completed: Bool
        var localPath: String?
        var error: String?
        let streamUrl: String
    }

    private var recordings: [String: RecordingEntry] = [:]

    func startDownload(request: DownloadRequest) async throws {
        var tracks: [String: TrackEntry] = [:]
        for t in request.tracks {
            tracks[t.filename] = TrackEntry(completed: false, streamUrl: t.streamUrl)
        }
        recordings[request.identifier] = RecordingEntry(
            state: .downloading(progress: 0),
            totalTracks: request.tracks.count,
            completedTracks: 0,
            concertID: request.concertID,
            artist: request.artist,
            date: request.date,
            venue: request.venue,
            tracks: tracks
        )
    }

    func downloadState(for identifier: String) async -> DownloadState {
        recordings[identifier]?.state ?? .notDownloaded
    }

    func allDownloads() async -> [DownloadRecord] {
        recordings.map { id, entry in
            DownloadRecord(identifier: id, concertID: entry.concertID, state: entry.state,
                           totalTracks: entry.totalTracks,
                           completedTracks: entry.completedTracks,
                           artist: entry.artist, date: entry.date,
                           venue: entry.venue)
        }
    }

    func completedDownloads() async -> [DownloadRecord] {
        recordings.compactMap { id, entry in
            guard entry.state == .downloaded else { return nil }
            return DownloadRecord(identifier: id, concertID: entry.concertID, state: entry.state,
                                  totalTracks: entry.totalTracks,
                                  completedTracks: entry.completedTracks,
                                  artist: entry.artist, date: entry.date,
                                  venue: entry.venue)
        }
    }

    func tracksForRecording(identifier: String) async -> [(filename: String, localPath: String)] {
        guard let entry = recordings[identifier] else { return [] }
        return entry.tracks.compactMap { filename, track in
            guard let path = track.localPath else { return nil }
            return (filename: filename, localPath: path)
        }
    }

    func markTrackComplete(identifier: String, filename: String,
                           localPath: String) async {
        guard var entry = recordings[identifier] else { return }
        entry.tracks[filename]?.completed = true
        entry.tracks[filename]?.localPath = localPath
        entry.completedTracks = entry.tracks.values.filter(\.completed).count
        let progress = Double(entry.completedTracks) / Double(max(entry.totalTracks, 1))
        entry.state = .downloading(progress: progress)
        recordings[identifier] = entry
    }

    func markTrackFailed(identifier: String, filename: String,
                         error: String) async {
        guard var entry = recordings[identifier] else { return }
        entry.tracks[filename]?.error = error
        entry.state = .failed(error)
        recordings[identifier] = entry
    }

    func markRecordingComplete(identifier: String) async {
        guard var entry = recordings[identifier] else { return }
        entry.state = .downloaded
        recordings[identifier] = entry
    }

    func deleteDownload(identifier: String) async throws {
        recordings.removeValue(forKey: identifier)
    }

    func isTrackDownloaded(identifier: String, filename: String) async -> Bool {
        recordings[identifier]?.tracks[filename]?.completed ?? false
    }

    func failedTracks(for identifier: String) async -> [(filename: String, streamUrl: String)] {
        guard let entry = recordings[identifier] else { return [] }
        return entry.tracks.compactMap { filename, track in
            guard !track.completed else { return nil }
            return (filename: filename, streamUrl: track.streamUrl)
        }
    }

    func findTrackByStreamURL(_ url: String) async -> (identifier: String, filename: String)? {
        for (identifier, entry) in recordings {
            for (filename, track) in entry.tracks where track.streamUrl == url {
                return (identifier: identifier, filename: filename)
            }
        }
        return nil
    }

    func resetTrack(identifier: String, filename: String) async {
        guard var entry = recordings[identifier] else { return }
        entry.tracks[filename]?.error = nil
        entry.tracks[filename]?.completed = false
        recordings[identifier] = entry
    }

    func markRecordingFailed(identifier: String, error: String) async {
        guard var entry = recordings[identifier] else { return }
        entry.state = .failed(error)
        recordings[identifier] = entry
    }
}

// MARK: - EnvironmentKey

private struct DownloadRepositoryKey: EnvironmentKey {
    static let defaultValue: any DownloadRepository = InMemoryDownloadRepository()
}

extension EnvironmentValues {
    var downloadRepository: any DownloadRepository {
        get { self[DownloadRepositoryKey.self] }
        set { self[DownloadRepositoryKey.self] = newValue }
    }
}
