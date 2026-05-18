import AVFoundation
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    var downloadManager: DownloadManager?

    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        if identifier == "com.tapescrape.downloads" {
            downloadManager?.backgroundCompletionHandler = completionHandler
        }
    }
}

@main
struct TapeScrapeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private static let dbURL: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("library.sqlite")
    }()

    private let library: any LibraryRepository
    private let playbackHistory: any PlaybackHistoryRepository
    private let downloads: any DownloadRepository
    @State private var playback: PlaybackCoordinator
    @State private var downloadManager: DownloadManager

    init() {
        let database = LibraryDatabase(url: TapeScrapeApp.dbURL)
        let history = SQLitePlaybackHistoryRepository(database: database)
        let storage = DocumentsAudioStorage()
        let dlRepo = SQLiteDownloadRepository(database: database)
        playbackHistory = history
        library = SQLiteLibraryRepository(database: database)
        downloads = dlRepo
        _playback = State(initialValue: PlaybackCoordinator(
            history: history, storage: storage
        ))
        _downloadManager = State(initialValue: DownloadManager(
            storage: storage, repository: dlRepo
        ))
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[TapeScrape] AVAudioSession setup failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(playback)
                .environment(downloadManager)
                .environment(\.libraryRepository, library)
                .environment(\.playbackHistoryRepository, playbackHistory)
                .environment(\.downloadRepository, downloads)
                .onAppear { appDelegate.downloadManager = downloadManager }
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
