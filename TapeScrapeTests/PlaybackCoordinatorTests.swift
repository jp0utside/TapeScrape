import Foundation
import Testing
@testable import TapeScrape

// Mock that captures calls and exposes callback closures for test-driven state injection.
final class MockPlayer: PlayerBackend {
    var onTrackEnd: (() -> Void)?
    var onPlaybackReady: (() -> Void)?
    var onPlaybackFailed: ((Error) -> Void)?
    var onPlaybackStalled: (() -> Void)?
    var onPlaybackResumed: (() -> Void)?
    var onTimeUpdate: ((TimeInterval, TimeInterval) -> Void)?

    private(set) var lastLoadedURL: URL?
    private(set) var playCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var lastSeekSeconds: TimeInterval?

    func replaceAndPlay(url: URL) { lastLoadedURL = url; playCallCount += 1 }
    func play()  { playCallCount += 1 }
    func pause() { pauseCallCount += 1 }
    func stop()  { stopCallCount += 1 }
    func seek(to seconds: TimeInterval) { lastSeekSeconds = seconds }
}

@MainActor
struct PlaybackCoordinatorTests {
    private func makeCoordinator() -> (PlaybackCoordinator, MockPlayer) {
        let mock = MockPlayer()
        return (PlaybackCoordinator(player: mock), mock)
    }

    private func makeTrack(
        index: Int = 0,
        url: String = "https://archive.org/download/x/track\(0).flac",
        duration: String? = "300"
    ) -> TrackResponse {
        TrackResponse(index: index, title: "Track \(index)", filename: "track\(index).flac",
                      duration: duration, streamUrl: url)
    }

    private func makeTracks(_ count: Int) -> [TrackResponse] {
        (0..<count).map { makeTrack(index: $0, url: "https://archive.org/download/x/track\($0).flac") }
    }

    // Convenience: drive coordinator to playing state.
    private func playAndReady(_ coordinator: PlaybackCoordinator, _ mock: MockPlayer,
                               tracks: [TrackResponse]? = nil, startingAt index: Int = 0) {
        let t = tracks ?? [makeTrack()]
        coordinator.play(t, startingAt: index)
        mock.onPlaybackReady?()
    }

    // MARK: - Initial state

    @Test func initialStateIsIdle() {
        let (coordinator, _) = makeCoordinator()
        #expect(coordinator.state.isIdle)
        #expect(coordinator.currentTrack == nil)
        #expect(coordinator.queue.isEmpty)
    }

    // MARK: - play(_:startingAt:)

    @Test func playLoadsTrackAndTransitionsToLoading() {
        let (coordinator, _) = makeCoordinator()
        coordinator.play([makeTrack()], startingAt: 0)
        #expect(coordinator.state.isLoading)
        #expect(coordinator.currentTrack != nil)
    }

    @Test func playSetsCurrentTrack() {
        let (coordinator, _) = makeCoordinator()
        let tracks = makeTracks(3)
        coordinator.play(tracks, startingAt: 2)
        #expect(coordinator.currentTrack?.index == 2)
        #expect(coordinator.currentIndex == 2)
    }

    @Test func playSetsQueue() {
        let (coordinator, _) = makeCoordinator()
        let tracks = makeTracks(4)
        coordinator.play(tracks, startingAt: 0)
        #expect(coordinator.queue.count == 4)
    }

    @Test func playCallsReplaceAndPlayOnBackend() {
        let (coordinator, mock) = makeCoordinator()
        coordinator.play([makeTrack()], startingAt: 0)
        #expect(mock.lastLoadedURL != nil)
        #expect(mock.playCallCount == 1)
    }

    @Test func playWithEmptyURLSetsFailedState() {
        let (coordinator, _) = makeCoordinator()
        let bad = TrackResponse(index: 0, title: nil, filename: "x.flac", duration: nil, streamUrl: "")
        coordinator.play([bad], startingAt: 0)
        #expect(coordinator.state.isFailed)
    }

    // MARK: - State transitions via callbacks

    @Test func onPlaybackReadyTransitionsLoadingToPlaying() {
        let (coordinator, mock) = makeCoordinator()
        coordinator.play([makeTrack()], startingAt: 0)
        #expect(coordinator.state.isLoading)
        mock.onPlaybackReady?()
        #expect(coordinator.state.isPlaying)
    }

    @Test func onPlaybackReadyIgnoredIfNotLoading() {
        let (coordinator, mock) = makeCoordinator()
        // Coordinator is idle — ready callback should be a no-op.
        mock.onPlaybackReady?()
        #expect(coordinator.state.isIdle)
    }

    @Test func onPlaybackFailedSetsFailedState() {
        let (coordinator, mock) = makeCoordinator()
        coordinator.play([makeTrack()], startingAt: 0)
        mock.onPlaybackFailed?(PlaybackError.invalidURL)
        #expect(coordinator.state.isFailed)
    }

    @Test func onPlaybackStalledTransitionsPlayingToStalled() {
        let (coordinator, mock) = makeCoordinator()
        playAndReady(coordinator, mock)
        mock.onPlaybackStalled?()
        #expect(coordinator.state.isStalled)
    }

    @Test func onPlaybackStalledIgnoredIfNotPlaying() {
        let (coordinator, mock) = makeCoordinator()
        coordinator.play([makeTrack()], startingAt: 0)
        // State is .loading; stalled should not fire.
        mock.onPlaybackStalled?()
        #expect(coordinator.state.isLoading)
    }

    @Test func onPlaybackResumedTransitionsStalledToPlaying() {
        let (coordinator, mock) = makeCoordinator()
        playAndReady(coordinator, mock)
        mock.onPlaybackStalled?()
        #expect(coordinator.state.isStalled)
        mock.onPlaybackResumed?()
        #expect(coordinator.state.isPlaying)
    }

    @Test func onPlaybackResumedIgnoredIfNotStalled() {
        let (coordinator, mock) = makeCoordinator()
        playAndReady(coordinator, mock)
        // Playing, not stalled — resumed should be no-op.
        mock.onPlaybackResumed?()
        #expect(coordinator.state.isPlaying)
    }

    // MARK: - togglePlayPause

    @Test func togglePausesWhenPlaying() {
        let (coordinator, mock) = makeCoordinator()
        playAndReady(coordinator, mock)
        coordinator.togglePlayPause()
        #expect(coordinator.state.isPaused)
        #expect(mock.pauseCallCount == 1)
    }

    @Test func toggleResumesWhenPaused() {
        let (coordinator, mock) = makeCoordinator()
        playAndReady(coordinator, mock)
        coordinator.togglePlayPause()  // → paused
        coordinator.togglePlayPause()  // → playing
        #expect(coordinator.state.isPlaying)
        #expect(mock.playCallCount == 2) // replaceAndPlay + resume
    }

    @Test func toggleIsNoOpWhenIdle() {
        let (coordinator, _) = makeCoordinator()
        coordinator.togglePlayPause()
        #expect(coordinator.state.isIdle)
    }

    // MARK: - skipForward / skipBack

    @Test func skipForwardAdvancesIndex() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(3)
        playAndReady(coordinator, mock, tracks: tracks, startingAt: 0)
        coordinator.skipForward()
        #expect(coordinator.currentIndex == 1)
        #expect(coordinator.currentTrack?.index == 1)
    }

    @Test func skipForwardAtEndStops() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(2)
        playAndReady(coordinator, mock, tracks: tracks, startingAt: 1)
        coordinator.skipForward()
        #expect(coordinator.state.isIdle)
    }

    @Test func skipBackRestartWhenElapsedOver3s() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(3)
        playAndReady(coordinator, mock, tracks: tracks, startingAt: 1)
        // Simulate 5 seconds elapsed.
        mock.onTimeUpdate?(5, 300)
        coordinator.skipBack()
        #expect(coordinator.currentIndex == 1)  // still on same track
        #expect(mock.lastSeekSeconds == 0)
    }

    @Test func skipBackGoesToPreviousWhenEarlyInTrack() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(3)
        playAndReady(coordinator, mock, tracks: tracks, startingAt: 1)
        // Simulate 1 second elapsed.
        mock.onTimeUpdate?(1, 300)
        coordinator.skipBack()
        #expect(coordinator.currentIndex == 0)
    }

    @Test func skipBackAtIndexZeroRestarts() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(3)
        playAndReady(coordinator, mock, tracks: tracks, startingAt: 0)
        mock.onTimeUpdate?(1, 300)
        coordinator.skipBack()
        // Index 0 always restarts, even if < 3s.
        #expect(coordinator.currentIndex == 0)
        #expect(mock.lastSeekSeconds == 0)
    }

    // MARK: - auto-advance via onTrackEnd

    @Test func onTrackEndAdvancesQueue() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(3)
        playAndReady(coordinator, mock, tracks: tracks, startingAt: 0)
        mock.onTrackEnd?()
        #expect(coordinator.currentIndex == 1)
    }

    @Test func onTrackEndStopsAtQueueEnd() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(2)
        playAndReady(coordinator, mock, tracks: tracks, startingAt: 1)
        mock.onTrackEnd?()
        #expect(coordinator.state.isIdle)
    }

    // MARK: - retry

    @Test func retryFromFailedReplaysCurrentTrack() {
        let (coordinator, mock) = makeCoordinator()
        coordinator.play([makeTrack()], startingAt: 0)
        mock.onPlaybackFailed?(PlaybackError.invalidURL)
        #expect(coordinator.state.isFailed)
        let prevPlayCount = mock.playCallCount
        coordinator.retry()
        #expect(mock.playCallCount == prevPlayCount + 1)
        #expect(coordinator.state.isLoading)
    }

    @Test func retryIsNoOpWhenNotFailed() {
        let (coordinator, mock) = makeCoordinator()
        coordinator.retry()
        #expect(coordinator.state.isIdle)
        #expect(mock.playCallCount == 0)
    }

    // MARK: - seek

    @Test func seekCallsThroughToBackend() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(1)
        playAndReady(coordinator, mock, tracks: tracks)
        mock.onTimeUpdate?(0, 100)  // set duration = 100
        coordinator.seek(to: 0.5)
        #expect(mock.lastSeekSeconds == 50)
    }

    @Test func seekUpdatesElapsed() {
        let (coordinator, mock) = makeCoordinator()
        playAndReady(coordinator, mock)
        mock.onTimeUpdate?(0, 200)
        coordinator.seek(to: 0.25)
        #expect(coordinator.elapsed == 50)
    }

    // MARK: - stop

    @Test func stopTransitionsToIdle() {
        let (coordinator, mock) = makeCoordinator()
        playAndReady(coordinator, mock)
        coordinator.stop()
        #expect(coordinator.state.isIdle)
        #expect(coordinator.currentTrack == nil)
        #expect(mock.stopCallCount == 1)
    }

    // MARK: - isActive

    @Test func stateIsActiveWhenLoadingOrPlayingOrPaused() {
        let (coordinator, mock) = makeCoordinator()
        #expect(!coordinator.state.isActive)
        coordinator.play([makeTrack()], startingAt: 0)
        #expect(coordinator.state.isActive)  // loading
        mock.onPlaybackReady?()
        #expect(coordinator.state.isActive)  // playing
        coordinator.togglePlayPause()
        #expect(coordinator.state.isActive)  // paused
        coordinator.stop()
        #expect(!coordinator.state.isActive)
    }

    // MARK: - playNewTrackReplaces

    @Test func playNewTrackReplacesCurrentTrack() {
        let (coordinator, mock) = makeCoordinator()
        playAndReady(coordinator, mock, tracks: [makeTrack(index: 0)])
        let newTracks = [makeTrack(index: 1)]
        coordinator.play(newTracks, startingAt: 0)
        #expect(coordinator.currentTrack?.index == 1)
    }

    // MARK: - durationSeconds extension

    @Test func durationSecondsDecimalString() {
        let track = TrackResponse(index: 0, title: nil, filename: "x.flac",
                                  duration: "312.02", streamUrl: "https://x")
        #expect(abs((track.durationSeconds ?? 0) - 312.02) < 0.01)
    }

    @Test func durationSecondsMinuteColonSecond() {
        let track = TrackResponse(index: 0, title: nil, filename: "x.flac",
                                  duration: "5:12", streamUrl: "https://x")
        #expect(track.durationSeconds == 312)
    }

    @Test func durationSecondsNilWhenMissing() {
        let track = TrackResponse(index: 0, title: nil, filename: "x.flac",
                                  duration: nil, streamUrl: "https://x")
        #expect(track.durationSeconds == nil)
    }
}
