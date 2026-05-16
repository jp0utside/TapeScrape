import SwiftUI

@main
struct TapeScrapeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    private let router = DeepLinkRouter()

    var body: some View {
        TabView {
            HomeTab()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            SearchTab()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            LibraryTab()
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }
        }
        .onOpenURL { url in
            if let destination = router.resolve(url) {
                print("[DeepLink] resolved: \(destination)")
            }
        }
    }
}
