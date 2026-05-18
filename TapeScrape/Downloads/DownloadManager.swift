import Foundation
import Observation

@Observable
@MainActor
final class DownloadManager: NSObject {
    private(set) var recordingProgress: [String: DownloadState] = [:]

    private var session: URLSession!
    private let storage: AudioStorage
    private let repository: any DownloadRepository
    private var taskMap: [Int: (identifier: String, filename: String)] = [:]
    var backgroundCompletionHandler: (() -> Void)?
    private var restoreTask: Task<Void, Never>?

    init(storage: AudioStorage, repository: any DownloadRepository) {
        self.storage = storage
        self.repository = repository
        super.init()
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.tapescrape.downloads"
        )
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        restoreTask = Task { await restoreState() }
    }

    /// Completes when launch-time restore has finished. Production callers never need this.
    func whenRestored() async { await restoreTask?.value }

    func download(recording: RecordingResponse, concert: ConcertContext) {
        let request = DownloadRequest(
            identifier: recording.identifier,
            tracks: recording.tracks.map { ($0.filename, $0.streamUrl) },
            concertID: concert.concertID,
            artist: concert.artist,
            date: concert.date,
            venue: concert.venue
        )
        recordingProgress[recording.identifier] = .downloading(progress: 0)
        Task {
            try? await repository.startDownload(request: request)
            for track in recording.tracks {
                guard let url = URL(string: track.streamUrl) else { continue }
                let task = session.downloadTask(with: url)
                taskMap[task.taskIdentifier] = (recording.identifier, track.filename)
                task.resume()
            }
        }
    }

    func recordingState(for identifier: String) -> DownloadState {
        recordingProgress[identifier] ?? .notDownloaded
    }

    func storageUsage() -> UInt64 {
        (try? storage.usage()) ?? 0
    }

    func retryDownload(identifier: String) {
        Task {
            let tracks = await repository.failedTracks(for: identifier)
            guard !tracks.isEmpty else { return }
            let downloads = await repository.allDownloads()
            if let record = downloads.first(where: { $0.identifier == identifier }) {
                let initialProgress = Double(record.completedTracks) / Double(max(record.totalTracks, 1))
                recordingProgress[identifier] = .downloading(progress: initialProgress)
            } else {
                recordingProgress[identifier] = .downloading(progress: 0)
            }
            for track in tracks {
                await repository.resetTrack(identifier: identifier, filename: track.filename)
            }
            for track in tracks {
                guard let url = URL(string: track.streamUrl) else { continue }
                let task = session.downloadTask(with: url)
                taskMap[task.taskIdentifier] = (identifier, track.filename)
                task.resume()
            }
        }
    }

    func deleteDownload(identifier: String) {
        Task {
            try? storage.deleteRecording(identifier: identifier)
            try? await repository.deleteDownload(identifier: identifier)
            recordingProgress.removeValue(forKey: identifier)
        }
    }

    private func restoreState() async {
        await rehydrateTaskMap()
        let activeIDs = Set(taskMap.values.map(\.identifier))
        let downloads = await repository.allDownloads()
        for record in downloads {
            if activeIDs.contains(record.identifier) {
                let p = Double(record.completedTracks) / Double(max(record.totalTracks, 1))
                recordingProgress[record.identifier] = .downloading(progress: p)
            } else {
                recordingProgress[record.identifier] = record.state
            }
        }
    }

    private func rehydrateTaskMap() async {
        let tasks: [URLSessionTask] = await withCheckedContinuation { continuation in
            session.getAllTasks { continuation.resume(returning: $0) }
        }
        for task in tasks {
            guard let url = task.originalRequest?.url?.absoluteString else {
                task.cancel()
                continue
            }
            if let match = await repository.findTrackByStreamURL(url) {
                taskMap[task.taskIdentifier] = (match.identifier, match.filename)
            } else {
                task.cancel()
            }
        }
        let activeIdentifiers = Set(taskMap.values.map(\.identifier))
        let downloads = await repository.allDownloads()
        for record in downloads where !activeIdentifiers.contains(record.identifier) {
            if case .downloading = record.state {
                await repository.markRecordingFailed(
                    identifier: record.identifier,
                    error: "Download interrupted — tap to retry"
                )
            }
        }
    }

    private func checkRecordingCompletion(identifier: String) {
        Task {
            let downloads = await repository.allDownloads()
            guard let record = downloads.first(where: { $0.identifier == identifier }) else { return }
            if record.completedTracks >= record.totalTracks {
                await repository.markRecordingComplete(identifier: identifier)
                recordingProgress[identifier] = .downloaded
            } else {
                let progress = Double(record.completedTracks) / Double(max(record.totalTracks, 1))
                recordingProgress[identifier] = .downloading(progress: progress)
            }
        }
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        // Read the file data on the delegate queue (background) before dispatching to MainActor.
        let taskID = downloadTask.taskIdentifier
        let result: Result<Data, Error>
        do {
            result = .success(try Data(contentsOf: location))
        } catch {
            result = .failure(error)
        }
        Task { @MainActor [weak self] in
            guard let self, let mapping = self.taskMap[taskID] else { return }
            let identifier = mapping.identifier
            let filename = mapping.filename
            switch result {
            case .success(let data):
                do {
                    try self.storage.store(data, identifier: identifier, file: filename)
                    let localPath = self.storage.url(for: identifier, file: filename)?.path ?? ""
                    await self.repository.markTrackComplete(
                        identifier: identifier, filename: filename, localPath: localPath
                    )
                    self.taskMap.removeValue(forKey: taskID)
                    self.checkRecordingCompletion(identifier: identifier)
                } catch {
                    await self.repository.markTrackFailed(
                        identifier: identifier, filename: filename,
                        error: error.localizedDescription
                    )
                    self.taskMap.removeValue(forKey: taskID)
                    self.recordingProgress[identifier] = .failed(error.localizedDescription)
                }
            case .failure(let error):
                await self.repository.markTrackFailed(
                    identifier: identifier, filename: filename,
                    error: error.localizedDescription
                )
                self.taskMap.removeValue(forKey: taskID)
                self.recordingProgress[identifier] = .failed(error.localizedDescription)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) {
        let taskID = downloadTask.taskIdentifier
        let written = totalBytesWritten
        let expected = totalBytesExpectedToWrite
        Task { @MainActor [weak self] in
            guard let self, let mapping = self.taskMap[taskID] else { return }
            let identifier = mapping.identifier
            let downloads = await self.repository.allDownloads()
            guard let record = downloads.first(where: { $0.identifier == identifier }) else { return }
            let trackFraction: Double = expected > 0 ? Double(written) / Double(expected) : 0
            let completedFraction = Double(record.completedTracks) / Double(max(record.totalTracks, 1))
            let perTrackWeight = 1.0 / Double(max(record.totalTracks, 1))
            let progress = completedFraction + trackFraction * perTrackWeight
            self.recordingProgress[identifier] = .downloading(progress: min(progress, 1.0))
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        guard let error else { return }
        let taskID = task.taskIdentifier
        let errorMessage = error.localizedDescription
        Task { @MainActor [weak self] in
            guard let self, let mapping = self.taskMap[taskID] else { return }
            let identifier = mapping.identifier
            let filename = mapping.filename
            await self.repository.markTrackFailed(
                identifier: identifier, filename: filename,
                error: errorMessage
            )
            self.taskMap.removeValue(forKey: taskID)
            self.recordingProgress[identifier] = .failed(errorMessage)
        }
    }

    nonisolated func urlSessionDidFinishEvents(
        forBackgroundURLSession session: URLSession
    ) {
        Task { @MainActor [weak self] in
            self?.backgroundCompletionHandler?()
            self?.backgroundCompletionHandler = nil
        }
    }
}
