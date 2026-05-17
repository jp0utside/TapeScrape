import SwiftUI

struct HomeTab: View {
    @State private var concert: ConcertResponse?
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading Cornell '77…")
                } else if let concert {
                    List {
                        NavigationLink(destination: ConcertDetailView(concert: concert)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Grateful Dead")
                                    .font(.headline)
                                Text("May 8, 1977 — Barton Hall, Cornell University")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else if let error = loadError {
                    VStack(spacing: 12) {
                        Text("Could not reach the backend.")
                            .foregroundStyle(.secondary)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Retry") { Task { await loadConcert() } }
                    }
                    .padding()
                }
            }
            .navigationTitle("Home")
        }
        .task { await loadConcert() }
    }

    private func loadConcert() async {
        guard concert == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            concert = try await CatalogClient.shared.getConcert(id: "gd-1977-05-08")
        } catch {
            loadError = error.localizedDescription
        }
    }
}
