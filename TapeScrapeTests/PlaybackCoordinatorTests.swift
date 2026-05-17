import Foundation
import Testing
@testable import TapeScrape

// Captures calls without touching AVFoundation.
final class MockPlayer: PlayerBackend {
    private(set) var lastLoadedURL: URL?
    private(set) var playCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var stopCallCount = 0

    func replaceAndPlay(url: URL) { lastLoadedURL = url; playCallCount += 1 }
    func play()  { playCallCount += 1 }
    func pause() { pauseCallCount += 1 }
    func stop()  { stopCallCount += 1 }
}

@MainActor
struct PlaybackCoordinatorTests {
    private func makeCoordinator() -> (PlaybackCoordinator, MockPlayer) {
        let mock = MockPlayer()
        return (PlaybackCoordinator(player: mock), mock)
    }

    private func makeTrack(index: Int = 0, url: String = "https://archive.org/download/x/track\(0).flac") -> TrackResponse {
        TrackResponse(index: index, title: "Track \(index)", filename: "track\(index).flac",
                      duration: "300", streamUrl: url)
    }

    // MARK: Initial state

    @Test func initialStateIsIdle() {
        let (coordinator, _) = makeCoordinator()
        #expect(coordinator.state.isIdle)
        #expect(coordinator.currentTrack == nil)
    }

    // MARK: play(_:)

    @Test func playTransitionsToPlaying() {
        let (coordinator, _) = makeCoordinator()
        coordinator.play(makeTrack())
        #expect(coordinator.state.isPlaying)
    }

    @Test func playSetsCurrentTrack() {
        let (coordinator, _) = makeCoordinator()
        let track = makeTrack(index: 3)
        coordinator.play(track)
        #expect(coordinator.currentTrack?.index == 3)
    }

    @Test func playCallsReplaceAndPlayOnBackend() {
        let (coordinator, mock) = makeCoordinator()
        coordinator.play(makeTrack())
        #expect(mock.lastLoadedURL != nil)
        #expect(mock.playCallCount == 1)
    }

    @Test func playWithEmptyURLSetsFailedState() {
        let (coordinator, _) = makeCoordinator()
        let bad = TrackResponse(index: 0, title: nil, filename: "x.flac", duration: nil, streamUrl: "")
        coordinator.play(bad)
        #expect(coordinator.state.isFailed)
    }

    // MARK: togglePlayPause()

    @Test func togglePausesWhenPlaying() {
        let (coordinator, mock) = makeCoordinator()
        coordinator.play(makeTrack())
        coordinator.togglePlayPause()
        #expect(coordinator.state.isPaused)
        #expect(mock.pauseCallCount == 1)
    }

    @Test func toggleResumesWhenPaused() {
        let (coordinator, mock) = makeCoordinator()
        coordinator.play(makeTrack())
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

    // MARK: Replacing tracks

    @Test func playNewTrackReplacesCurrentTrack() {
        let (coordinator, _) = makeCoordinator()
        coordinator.play(makeTrack(index: 0))
        coordinator.play(makeTrack(index: 1))
        #expect(coordinator.currentTrack?.index == 1)
        #expect(coordinator.state.isPlaying)
    }

    // MARK: stop()

    @Test func stopTransitionsToIdle() {
        let (coordinator, mock) = makeCoordinator()
        coordinator.play(makeTrack())
        coordinator.stop()
        #expect(coordinator.state.isIdle)
        #expect(coordinator.currentTrack == nil)
        #expect(mock.stopCallCount == 1)
    }

    // MARK: isActive

    @Test func stateIsActiveWhenPlayingOrPaused() {
        let (coordinator, _) = makeCoordinator()
        #expect(!coordinator.state.isActive)
        coordinator.play(makeTrack())
        #expect(coordinator.state.isActive)
        coordinator.togglePlayPause()
        #expect(coordinator.state.isActive)
        coordinator.stop()
        #expect(!coordinator.state.isActive)
    }
}
