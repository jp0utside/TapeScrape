import Foundation
import Testing
@testable import TapeScrape

actor MockPlaybackHistoryRepository: PlaybackHistoryRepository {
    private(set) var recordedPlays: [(identifier: String, trackFile: String, context: ConcertContext)] = []

    func recordPlay(identifier: String, trackFile: String, at: Date,
                    context: ConcertContext) async throws {
        recordedPlays.append((identifier: identifier, trackFile: trackFile, context: context))
    }

    func recentPlays(limit: Int) async -> [PlayRecord] { [] }
    func recentConcerts(limit: Int) async -> [RecentConcert] { [] }
    func distinctArtists(limit: Int) async -> [EngagedArtist] { [] }
}

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
    private func makeCoordinator(history: (any PlaybackHistoryRepository)? = nil)
        -> (PlaybackCoordinator, MockPlayer) {
        let mock = MockPlayer()
        let h = history ?? InMemoryPlaybackHistoryRepository()
        return (PlaybackCoordinator(player: mock, history: h), mock)
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

    // MARK: - history recording

    @Test func playbackReadyRecordsPlayWhenContextIsSet() async {
        let mockHistory = MockPlaybackHistoryRepository()
        let (coordinator, mock) = makeCoordinator(history: mockHistory)
        let ctx = ConcertContext(concertID: "gd1977-05-08", recordingIdentifier: "gd77.sbd",
                                 artist: "Grateful Dead", date: "1977-05-08", venue: "Barton Hall")
        coordinator.play([makeTrack()], startingAt: 0, concert: ctx)
        mock.onPlaybackReady?()
        // Yield so the fire-and-forget Task can execute.
        await Task.yield()
        let plays = await mockHistory.recordedPlays
        #expect(plays.count == 1)
        #expect(plays[0].identifier == "gd77.sbd")
        #expect(plays[0].trackFile == "track0.flac")
    }

    @Test func playbackReadyDoesNotRecordWithoutConcertContext() async {
        let mockHistory = MockPlaybackHistoryRepository()
        let (coordinator, mock) = makeCoordinator(history: mockHistory)
        // No concert context passed — history should not record.
        coordinator.play([makeTrack()], startingAt: 0)
        mock.onPlaybackReady?()
        await Task.yield()
        let plays = await mockHistory.recordedPlays
        #expect(plays.isEmpty)
    }

    // MARK: - playNext

    @Test func playNextInsertsAfterCurrent() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(3)
        playAndReady(coordinator, mock, tracks: tracks, startingAt: 0)
        coordinator.playNext([makeTrack(index: 10, url: "https://archive.org/download/x/track10.flac")])
        #expect(coordinator.queue.count == 4)
        #expect(coordinator.queue[1].track.index == 10)
        #expect(coordinator.currentIndex == 0)
        #expect(coordinator.state.isPlaying)
    }

    @Test func playNextWhenIdleStartsPlayback() {
        let (coordinator, _) = makeCoordinator()
        coordinator.playNext([makeTrack()])
        #expect(coordinator.state.isLoading)
        #expect(coordinator.currentIndex == 0)
        #expect(coordinator.queue.count == 1)
    }

    // MARK: - addToEnd

    @Test func addToEndAppendsTrack() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(3)
        playAndReady(coordinator, mock, tracks: tracks, startingAt: 0)
        coordinator.addToEnd([makeTrack(index: 10, url: "https://archive.org/download/x/track10.flac")])
        #expect(coordinator.queue.count == 4)
        #expect(coordinator.queue[3].track.index == 10)
        #expect(coordinator.currentIndex == 0)
        #expect(coordinator.state.isPlaying)
    }

    @Test func addToEndWhenIdleStartsPlayback() {
        let (coordinator, _) = makeCoordinator()
        coordinator.addToEnd([makeTrack()])
        #expect(coordinator.state.isLoading)
        #expect(coordinator.currentIndex == 0)
        #expect(coordinator.queue.count == 1)
    }

    // MARK: - removeFromQueue

    @Test func removeBeforeCurrentDecrementsIndex() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(3)
        playAndReady(coordinator, mock, tracks: tracks, startingAt: 2)
        coordinator.removeFromQueue(at: 0)
        #expect(coordinator.currentIndex == 1)
        #expect(coordinator.queue.count == 2)
        #expect(coordinator.state.isPlaying)
    }

    @Test func removeCurrentAdvancesToNext() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(3)
        playAndReady(coordinator, mock, tracks: tracks, startingAt: 0)
        coordinator.removeFromQueue(at: 0)
        #expect(coordinator.currentIndex == 0)
        #expect(coordinator.queue.count == 2)
        #expect(coordinator.state.isLoading)
    }

    @Test func removeCurrentAtEndStops() {
        let (coordinator, mock) = makeCoordinator()
        playAndReady(coordinator, mock, tracks: [makeTrack()])
        coordinator.removeFromQueue(at: 0)
        #expect(coordinator.state.isIdle)
        #expect(coordinator.queue.isEmpty)
    }

    @Test func removeAfterCurrentDoesNotChangeIndex() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(3)
        playAndReady(coordinator, mock, tracks: tracks, startingAt: 0)
        coordinator.removeFromQueue(at: 2)
        #expect(coordinator.currentIndex == 0)
        #expect(coordinator.queue.count == 2)
        #expect(coordinator.state.isPlaying)
    }

    // MARK: - moveInQueue

    @Test func moveInQueueCurrentFollows() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(4)
        playAndReady(coordinator, mock, tracks: tracks, startingAt: 0)
        // Move current item (index 0) to position 2 → [1, 0, 2, 3]
        coordinator.moveInQueue(from: 0, to: 2)
        #expect(coordinator.currentIndex == 1)
        #expect(coordinator.queue[1].track.index == 0)
        #expect(coordinator.state.isPlaying)
    }

    @Test func moveInQueueMoveBeforeCurrentShiftsIndex() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(4)
        playAndReady(coordinator, mock, tracks: tracks, startingAt: 2)
        // Move item at index 3 to before index 0 → [3, 0, 1, 2]
        coordinator.moveInQueue(from: 3, to: 0)
        #expect(coordinator.currentIndex == 3)
        #expect(coordinator.queue[3].track.index == 2)
        #expect(coordinator.state.isPlaying)
    }

    @Test func moveInQueueNonCurrentAfterCurrent() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(4)
        playAndReady(coordinator, mock, tracks: tracks, startingAt: 0)
        // Move item at index 2 to end — current stays at 0
        coordinator.moveInQueue(from: 2, to: 4)
        #expect(coordinator.currentIndex == 0)
        #expect(coordinator.state.isPlaying)
    }

    // MARK: - skipTo

    @Test func skipToJumpsWithinQueue() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(4)
        playAndReady(coordinator, mock, tracks: tracks, startingAt: 0)
        coordinator.skipTo(index: 3)
        #expect(coordinator.currentIndex == 3)
        #expect(coordinator.currentTrack?.index == 3)
        #expect(coordinator.state.isLoading)
    }

    @Test func skipToOutOfBoundsIsNoOp() {
        let (coordinator, mock) = makeCoordinator()
        let tracks = makeTracks(3)
        playAndReady(coordinator, mock, tracks: tracks, startingAt: 0)
        coordinator.skipTo(index: 10)
        #expect(coordinator.currentIndex == 0)
        #expect(coordinator.state.isPlaying)
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
