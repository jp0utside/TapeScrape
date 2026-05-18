import AVFoundation
import SwiftUI

@main
struct TapeScrapeApp: App {
    private static let dbURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("library.sqlite")

    private let library: any LibraryRepository
    private let playbackHistory: any PlaybackHistoryRepository
    @State private var playback: PlaybackCoordinator

    init() {
        let history = SQLitePlaybackHistoryRepository(dbURL: TapeScrapeApp.dbURL)
        playbackHistory = history
        library = SQLiteLibraryRepository(dbURL: TapeScrapeApp.dbURL)
        _playback = State(initialValue: PlaybackCoordinator(history: history))
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Non-fatal — audio may still play; logged for debugging.
            print("[TapeScrape] AVAudioSession setup failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(playback)
                .environment(\.libraryRepository, library)
                .environment(\.playbackHistoryRepository, playbackHistory)
        }
    }
}

struct ContentView: View {
    private let router = DeepLinkRouter()
    @Environment(PlaybackCoordinator.self) private var playback
    @State private var showNowPlaying = false

    var body: some View {
        TabView {
            HomeTab()
                .tabItem { Label("Home", systemImage: "house") }
            SearchTab()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            LibraryTab()
                .tabItem { Label("Library", systemImage: "music.note.list") }
        }
        .safeAreaInset(edge: .bottom) {
            if playback.state.isActive {
                MiniPlayerView(showNowPlaying: $showNowPlaying)
            }
        }
        .fullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView()
                .environment(playback)
        }
        .onOpenURL { url in
            if let destination = router.resolve(url) {
                print("[DeepLink] resolved: \(destination)")
            }
        }
    }
}
