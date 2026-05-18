import Testing
import Foundation
@testable import TapeScrape

// Protocol contract tests for LibraryRepository using InMemoryLibraryRepository.
// These verify the in-memory stub (used by other tests and previews) upholds the
// same contract as the SQLite-backed implementation.
@Suite("InMemoryLibraryRepository (protocol contract)")
struct LibraryRepositoryTests {
    private func makeRepo() -> InMemoryLibraryRepository {
        InMemoryLibraryRepository()
    }

    private func makeSnapshot(id: String = "concert-1") -> ConcertSnapshot {
        ConcertSnapshot(
            id: id,
            artist: "Grateful Dead",
            date: "1977-05-08",
            venue: "Barton Hall",
            location: "Ithaca, NY"
        )
    }

    @Test("System favorite tag is present after init")
    func systemFavoriteTagPresent() async {
        let repo = makeRepo()
        let tags = await repo.tags()
        #expect(tags.contains { $0.id == Tag.favoriteTagID })
    }

    @Test("isFavorited returns false initially")
    func isFavoritedInitiallyFalse() async {
        let repo = makeRepo()
        #expect(await !repo.isFavorited("concert-1"))
    }

    @Test("setFavorite true → isFavorited true")
    func setFavoriteTrueMakesIsFavoritedTrue() async throws {
        let repo = makeRepo()
        try await repo.setFavorite(makeSnapshot(), isFavorite: true)
        #expect(await repo.isFavorited("concert-1"))
    }

    @Test("setFavorite false → isFavorited false")
    func setFavoriteFalseRemoves() async throws {
        let repo = makeRepo()
        try await repo.setFavorite(makeSnapshot(), isFavorite: true)
        try await repo.setFavorite(makeSnapshot(), isFavorite: false)
        #expect(await !repo.isFavorited("concert-1"))
    }

    @Test("favoritedConcerts returns correct snapshot")
    func favoritedConcertsReturnsSnapshot() async throws {
        let repo = makeRepo()
        let snap = makeSnapshot()
        try await repo.setFavorite(snap, isFavorite: true)
        let favorites = await repo.favoritedConcerts()
        #expect(favorites.count == 1)
        #expect(favorites.first?.id == snap.id)
    }

    @Test("favoritedConcerts is empty after unfavoriting")
    func favoritedConcertsEmptyAfterRemove() async throws {
        let repo = makeRepo()
        try await repo.setFavorite(makeSnapshot(), isFavorite: true)
        try await repo.setFavorite(makeSnapshot(), isFavorite: false)
        #expect(await repo.favoritedConcerts().isEmpty)
    }

    @Test("setFavorite true twice is idempotent")
    func idempotentSetFavorite() async throws {
        let repo = makeRepo()
        try await repo.setFavorite(makeSnapshot(), isFavorite: true)
        try await repo.setFavorite(makeSnapshot(), isFavorite: true)
        let favorites = await repo.favoritedConcerts()
        #expect(favorites.count == 1)
    }

    @Test("tagItem and untagItem via base protocol")
    func tagAndUntagItem() async throws {
        let repo = makeRepo()
        try await repo.tagItem("item-1", with: Tag.favoriteTagID)
        var items = await repo.items(for: Tag.favoriteTagID)
        #expect(items.contains { $0.itemID == "item-1" })

        try await repo.untagItem("item-1", from: Tag.favoriteTagID)
        items = await repo.items(for: Tag.favoriteTagID)
        #expect(!items.contains { $0.itemID == "item-1" })
    }

    // MARK: - Playlist tests

    private func makePlaylistItem(sortOrder: Int = 0) -> PlaylistItem {
        PlaylistItem(
            id: UUID(),
            recordingIdentifier: "gd77.sbd",
            trackFilename: "track\(sortOrder).flac",
            streamURL: "https://archive.org/download/x/track\(sortOrder).flac",
            trackTitle: "Track \(sortOrder)",
            trackDuration: "5:00",
            trackIndex: sortOrder,
            sortOrder: sortOrder,
            concertID: "gd1977-05-08",
            artist: "Grateful Dead",
            date: "1977-05-08",
            venue: "Barton Hall"
        )
    }

    @Test("createPlaylist produces tag with playlist kind")
    func createPlaylistKind() async throws {
        let repo = makeRepo()
        let tag = try await repo.createPlaylist(name: "Road Trips")
        #expect(tag.kind == .playlist)
        #expect(tag.name == "Road Trips")
    }

    @Test("playlistTags returns only playlist-kind tags")
    func playlistTagsFiltered() async throws {
        let repo = makeRepo()
        _ = try await repo.createPlaylist(name: "Set 1")
        _ = try await repo.createPlaylist(name: "Set 2")
        let tags = await repo.playlistTags()
        #expect(tags.count == 2)
        #expect(tags.allSatisfy { $0.kind == .playlist })
        #expect(!tags.contains { $0.id == Tag.favoriteTagID })
    }

    @Test("addToPlaylist and playlistItems round-trips items in order")
    func addAndRetrieveItems() async throws {
        let repo = makeRepo()
        let tag = try await repo.createPlaylist(name: "Mix")
        let items = [makePlaylistItem(sortOrder: 0), makePlaylistItem(sortOrder: 1)]
        try await repo.addToPlaylist(id: tag.id, items: items)
        let retrieved = await repo.playlistItems(for: tag.id)
        #expect(retrieved.count == 2)
        #expect(retrieved[0].trackFilename == "track0.flac")
        #expect(retrieved[1].trackFilename == "track1.flac")
        #expect(retrieved[0].sortOrder < retrieved[1].sortOrder)
    }

    @Test("removeFromPlaylist removes item and renumbers")
    func removeFromPlaylist() async throws {
        let repo = makeRepo()
        let tag = try await repo.createPlaylist(name: "Mix")
        try await repo.addToPlaylist(id: tag.id, items: [
            makePlaylistItem(sortOrder: 0),
            makePlaylistItem(sortOrder: 1),
            makePlaylistItem(sortOrder: 2)
        ])
        var items = await repo.playlistItems(for: tag.id)
        try await repo.removeFromPlaylist(id: tag.id, at: items[0].sortOrder)
        items = await repo.playlistItems(for: tag.id)
        #expect(items.count == 2)
        #expect(items[0].sortOrder == 0)
        #expect(items[1].sortOrder == 1)
    }

    @Test("moveInPlaylist reorders correctly")
    func moveInPlaylist() async throws {
        let repo = makeRepo()
        let tag = try await repo.createPlaylist(name: "Mix")
        try await repo.addToPlaylist(id: tag.id, items: [
            makePlaylistItem(sortOrder: 0),
            makePlaylistItem(sortOrder: 1),
            makePlaylistItem(sortOrder: 2)
        ])
        var items = await repo.playlistItems(for: tag.id)
        let firstFilename = items[0].trackFilename
        try await repo.moveInPlaylist(id: tag.id, from: 0, to: 3)
        items = await repo.playlistItems(for: tag.id)
        #expect(items.last?.trackFilename == firstFilename)
    }

    @Test("deletePlaylist removes tag and all items")
    func deletePlaylist() async throws {
        let repo = makeRepo()
        let tag = try await repo.createPlaylist(name: "Temp")
        try await repo.addToPlaylist(id: tag.id, items: [makePlaylistItem()])
        try await repo.deletePlaylist(id: tag.id)
        let tags = await repo.playlistTags()
        #expect(!tags.contains { $0.id == tag.id })
        let items = await repo.playlistItems(for: tag.id)
        #expect(items.isEmpty)
    }

    @Test("renamePlaylist updates the tag name")
    func renamePlaylist() async throws {
        let repo = makeRepo()
        let tag = try await repo.createPlaylist(name: "Old Name")
        try await repo.renamePlaylist(id: tag.id, name: "New Name")
        let tags = await repo.playlistTags()
        #expect(tags.first { $0.id == tag.id }?.name == "New Name")
    }
}
