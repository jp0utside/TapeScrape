import AVFoundation
import Observation

// Internal seam — lets tests inject a mock without pulling in AVFoundation.
protocol PlayerBackend: AnyObject {
    func replaceAndPlay(url: URL)
    func play()
    func pause()
    func stop()
}

final class AVPlayerBackend: PlayerBackend {
    private let player = AVPlayer()

    func replaceAndPlay(url: URL) {
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()
    }

    func play() { player.play() }
    func pause() { player.pause() }
    func stop() { player.pause(); player.replaceCurrentItem(with: nil) }
}

@Observable
@MainActor
final class PlaybackCoordinator {
    enum State {
        case idle, loading, playing, paused, failed(Error)

        var isIdle: Bool    { if case .idle    = self { true } else { false } }
        var isLoading: Bool { if case .loading = self { true } else { false } }
        var isPlaying: Bool { if case .playing = self { true } else { false } }
        var isPaused: Bool  { if case .paused  = self { true } else { false } }
        var isFailed: Bool  { if case .failed  = self { true } else { false } }

        // True for any state where a mini-player should be visible.
        var isActive: Bool {
            switch self {
            case .idle: false
            default:    true
            }
        }
    }

    private(set) var state: State = .idle
    private(set) var currentTrack: TrackResponse?

    private let player: any PlayerBackend

    init(player: any PlayerBackend = AVPlayerBackend()) {
        self.player = player
    }

    func play(_ track: TrackResponse) {
        guard let url = URL(string: track.streamUrl), !track.streamUrl.isEmpty else {
            state = .failed(PlaybackError.invalidURL)
            return
        }
        currentTrack = track
        state = .loading
        player.replaceAndPlay(url: url)
        // Phase 1: transition to playing immediately after handing off to AVPlayer.
        // KVO-based buffering observation (loading → stalled → playing) is Phase 2.
        state = .playing
    }

    func togglePlayPause() {
        switch state {
        case .playing:
            player.pause()
            state = .paused
        case .paused:
            player.play()
            state = .playing
        default:
            break
        }
    }

    func stop() {
        player.stop()
        currentTrack = nil
        state = .idle
    }
}

enum PlaybackError: Error, LocalizedError {
    case invalidURL

    var errorDescription: String? { "Invalid or missing stream URL." }
}
