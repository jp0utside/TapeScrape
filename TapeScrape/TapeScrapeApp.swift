import AVFoundation
import SwiftUI

@main
struct TapeScrapeApp: App {
    @State private var playback = PlaybackCoordinator()

    init() {
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
        }
    }
}

struct ContentView: View {
    private let router = DeepLinkRouter()
    @Environment(PlaybackCoordinator.self) private var playback

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
                MiniPlayerView()
            }
        }
        .onOpenURL { url in
            if let destination = router.resolve(url) {
                print("[DeepLink] resolved: \(destination)")
            }
        }
    }
}
