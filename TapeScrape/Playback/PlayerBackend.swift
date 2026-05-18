import AVFoundation

protocol PlayerBackend: AnyObject {
    // Observation callbacks — set by PlaybackCoordinator before first use.
    var onTrackEnd: (() -> Void)? { get set }
    var onPlaybackReady: (() -> Void)? { get set }
    var onPlaybackFailed: ((Error) -> Void)? { get set }
    var onPlaybackStalled: (() -> Void)? { get set }
    var onPlaybackResumed: (() -> Void)? { get set }
    var onTimeUpdate: ((TimeInterval, TimeInterval) -> Void)? { get set }

    func replaceAndPlay(url: URL)
    func play()
    func pause()
    func stop()
    func seek(to seconds: TimeInterval)
}

final class AVPlayerBackend: PlayerBackend {
    var onTrackEnd: (() -> Void)?
    var onPlaybackReady: (() -> Void)?
    var onPlaybackFailed: ((Error) -> Void)?
    var onPlaybackStalled: (() -> Void)?
    var onPlaybackResumed: (() -> Void)?
    var onTimeUpdate: ((TimeInterval, TimeInterval) -> Void)?

    private let player = AVPlayer()
    private var itemObservations: [NSKeyValueObservation] = []
    private var playerObservation: NSKeyValueObservation?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    func replaceAndPlay(url: URL) {
        tearDownObservations()

        let item = AVPlayerItem(url: url)

        // Item status: readyToPlay → onPlaybackReady; failed → onPlaybackFailed
        itemObservations.append(item.observe(\.status, options: [.new]) { [weak self] item, _ in
            switch item.status {
            case .readyToPlay:
                DispatchQueue.main.async { self?.onPlaybackReady?() }
            case .failed:
                let err = item.error ?? PlaybackError.invalidURL
                DispatchQueue.main.async { self?.onPlaybackFailed?(err) }
            default:
                break
            }
        })

        // Player timeControlStatus: waiting → stalled; playing → resumed
        playerObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            switch player.timeControlStatus {
            case .waitingToPlayAtSpecifiedRate:
                DispatchQueue.main.async { self?.onPlaybackStalled?() }
            case .playing:
                DispatchQueue.main.async { self?.onPlaybackResumed?() }
            default:
                break
            }
        }

        // Track end
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in self?.onTrackEnd?() }

        // Periodic time updates
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self, weak item] time in
            guard let self, let item else { return }
            let elapsed = CMTimeGetSeconds(time)
            let raw = CMTimeGetSeconds(item.duration)
            let duration = raw.isFinite && raw > 0 ? raw : 0
            self.onTimeUpdate?(elapsed, duration)
        }

        player.replaceCurrentItem(with: item)
        player.play()
    }

    func play()  { player.play() }
    func pause() { player.pause() }

    func stop() {
        tearDownObservations()
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    func seek(to seconds: TimeInterval) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func tearDownObservations() {
        itemObservations.forEach { $0.invalidate() }
        itemObservations = []
        playerObservation?.invalidate()
        playerObservation = nil
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
    }

    deinit { tearDownObservations() }
}

enum PlaybackError: Error, LocalizedError {
    case invalidURL

    var errorDescription: String? { "Invalid or missing stream URL." }
}
