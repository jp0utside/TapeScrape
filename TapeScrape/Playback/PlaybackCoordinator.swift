import AVFoundation
import MediaPlayer
import Observation

struct QueueItem: Identifiable, Sendable {
    let id: UUID = UUID()
    let track: TrackResponse
    let concertContext: ConcertContext?
}

@Observable
@MainActor
final class PlaybackCoordinator {
    enum State {
        case idle, loading, playing, paused, stalled, failed(Error)

        var isIdle:    Bool { if case .idle    = self { true } else { false } }
        var isLoading: Bool { if case .loading = self { true } else { false } }
        var isPlaying: Bool { if case .playing = self { true } else { false } }
        var isPaused:  Bool { if case .paused  = self { true } else { false } }
        var isStalled: Bool { if case .stalled = self { true } else { false } }
        var isFailed:  Bool { if case .failed  = self { true } else { false } }

        var isActive: Bool {
            switch self {
            case .idle: false
            default:    true
            }
        }
    }

    private(set) var state: State = .idle
    private(set) var currentTrack: TrackResponse?
    private(set) var queue: [QueueItem] = []
    private(set) var currentIndex: Int = 0
    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    private let backend: any PlayerBackend
    private let history: any PlaybackHistoryRepository
    private let storage: AudioStorage

    init(player: any PlayerBackend = AVPlayerBackend(),
         history: any PlaybackHistoryRepository = InMemoryPlaybackHistoryRepository(),
         storage: AudioStorage = DocumentsAudioStorage()) {
        self.backend = player
        self.history = history
        self.storage = storage
        setupCallbacks()
        setupRemoteCommands()
        setupInterruptionHandling()
    }

    // MARK: - Public API

    func play(_ tracks: [TrackResponse], startingAt index: Int = 0,
              concert: ConcertContext? = nil) {
        queue = tracks.map { QueueItem(track: $0, concertContext: concert) }
        currentIndex = index
        loadCurrentTrack()
    }

    func playNext(_ tracks: [TrackResponse], concert: ConcertContext? = nil) {
        let items = tracks.map { QueueItem(track: $0, concertContext: concert) }
        if state.isIdle {
            queue = items
            currentIndex = 0
            loadCurrentTrack()
        } else {
            queue.insert(contentsOf: items, at: currentIndex + 1)
        }
    }

    func addToEnd(_ tracks: [TrackResponse], concert: ConcertContext? = nil) {
        let items = tracks.map { QueueItem(track: $0, concertContext: concert) }
        if state.isIdle {
            queue = items
            currentIndex = 0
            loadCurrentTrack()
        } else {
            queue.append(contentsOf: items)
        }
    }

    func removeFromQueue(at index: Int) {
        guard queue.indices.contains(index) else { return }
        queue.remove(at: index)
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex {
            if queue.isEmpty {
                stop()
            } else {
                currentIndex = min(currentIndex, queue.count - 1)
                loadCurrentTrack()
            }
        }
    }

    func moveInQueue(from source: Int, to destination: Int) {
        guard queue.indices.contains(source) else { return }
        let currentID = queue[currentIndex].id
        queue.move(fromOffsets: IndexSet(integer: source), toOffset: destination)
        if let newIndex = queue.firstIndex(where: { $0.id == currentID }) {
            currentIndex = newIndex
        }
    }

    func skipTo(index: Int) {
        guard queue.indices.contains(index) else { return }
        currentIndex = index
        loadCurrentTrack()
    }

    func togglePlayPause() {
        switch state {
        case .playing:
            backend.pause()
            state = .paused
        case .paused:
            backend.play()
            state = .playing
        default:
            break
        }
        updateNowPlayingInfo()
    }

    func skipForward() {
        let next = currentIndex + 1
        guard next < queue.count else {
            stop()
            return
        }
        currentIndex = next
        loadCurrentTrack()
    }

    func skipBack() {
        if elapsed > 3 || currentIndex == 0 {
            seek(to: 0)
            backend.seek(to: 0)
        } else {
            currentIndex -= 1
            loadCurrentTrack()
        }
    }

    func seek(to fraction: Double) {
        let seconds = fraction * duration
        backend.seek(to: seconds)
        elapsed = seconds
        updateNowPlayingInfo()
    }

    func retry() {
        guard case .failed = state else { return }
        loadCurrentTrack()
    }

    func stop() {
        backend.stop()
        currentTrack = nil
        state = .idle
        elapsed = 0
        duration = 0
        updateNowPlayingInfo()
    }

    // MARK: - Private

    private func loadCurrentTrack() {
        guard currentIndex < queue.count else {
            stop()
            return
        }
        let item = queue[currentIndex]
        let track = item.track
        currentTrack = track
        elapsed = 0
        duration = track.durationSeconds ?? 0

        let url: URL
        if let ctx = item.concertContext,
           storage.fileExists(identifier: ctx.recordingIdentifier, file: track.filename),
           let localURL = storage.url(for: ctx.recordingIdentifier, file: track.filename) {
            url = localURL
        } else {
            guard let remoteURL = URL(string: track.streamUrl), !track.streamUrl.isEmpty else {
                state = .failed(PlaybackError.invalidURL)
                return
            }
            url = remoteURL
        }
        state = .loading
        backend.replaceAndPlay(url: url)
        updateNowPlayingInfo()
    }

    private func setupCallbacks() {
        backend.onPlaybackReady = { [weak self] in
            guard let self, self.state.isLoading else { return }
            self.state = .playing
            self.updateNowPlayingInfo()
            let idx = self.currentIndex
            if let track = self.currentTrack,
               idx < self.queue.count,
               let ctx = self.queue[idx].concertContext {
                let h = self.history
                let file = track.filename
                Task {
                    try? await h.recordPlay(
                        identifier: ctx.recordingIdentifier,
                        trackFile: file,
                        at: Date(),
                        context: ctx
                    )
                }
            }
        }

        backend.onPlaybackFailed = { [weak self] error in
            guard let self else { return }
            self.state = .failed(error)
            self.updateNowPlayingInfo()
        }

        backend.onPlaybackStalled = { [weak self] in
            guard let self, self.state.isPlaying else { return }
            self.state = .stalled
            self.updateNowPlayingInfo()
        }

        backend.onPlaybackResumed = { [weak self] in
            guard let self, self.state.isStalled else { return }
            self.state = .playing
            self.updateNowPlayingInfo()
        }

        backend.onTrackEnd = { [weak self] in
            self?.skipForward()
        }

        backend.onTimeUpdate = { [weak self] elapsed, duration in
            guard let self else { return }
            self.elapsed = elapsed
            if duration > 0 { self.duration = duration }
            self.updateNowPlayingInfo()
        }
    }

    // MARK: - MPRemoteCommandCenter

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.state.isPaused { self.togglePlayPause() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.state.isPlaying { self.togglePlayPause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.togglePlayPause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.skipForward()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.skipBack()
            return .success
        }
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let e = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let fraction = self.duration > 0 ? e.positionTime / self.duration : 0
            self.seek(to: fraction)
            return .success
        }
    }

    // MARK: - MPNowPlayingInfoCenter

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title ?? track.filename,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPMediaItemPropertyPlaybackDuration: max(duration, 1),
            MPNowPlayingInfoPropertyPlaybackRate: state.isPlaying ? 1.0 : 0.0,
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - AVAudioSession interruption

    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract Sendable primitives before crossing actor boundary.
            guard let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt else { return }
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }
    }

    private func handleInterruption(typeValue: UInt, optionsValue: UInt?) {
        guard let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            if state.isPlaying || state.isStalled {
                backend.pause()
                state = .paused
                updateNowPlayingInfo()
            }
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
            if options.contains(.shouldResume) && state.isPaused {
                backend.play()
                state = .playing
                updateNowPlayingInfo()
            }
        @unknown default:
            break
        }
    }
}

