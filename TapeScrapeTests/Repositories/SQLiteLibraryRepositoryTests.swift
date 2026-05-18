import Testing
import Foundation
@testable import TapeScrape

// SQLite-backed repository tests. Each test gets a fresh temp-file DB so state
// doesn't leak between tests.
@Suite("SQLiteLibraryRepository")
struct SQLiteLibraryRepositoryTests {
    private func makeRepo() -> SQLiteLibraryRepository {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".sqlite")
        return SQLiteLibraryRepository(dbURL: url)
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

    @Test("System favorite tag is seeded on init")
    func systemFavoriteTagSeeded() async {
        let repo = makeRepo()
        let tags = await repo.tags()
        #expect(tags.contains { $0.id == Tag.favoriteTagID })
        #expect(tags.contains { $0.kind == .favorite })
    }

    @Test("isFavorited returns false before any favorite is set")
    func isFavoritedInitiallyFalse() async {
        let repo = makeRepo()
        let result = await repo.isFavorited("concert-1")
        #expect(!result)
    }

    @Test("setFavorite true makes isFavorited return true")
    func setFavoriteTrue() async throws {
        let repo = makeRepo()
        try await repo.setFavorite(makeSnapshot(), isFavorite: true)
        let result = await repo.isFavorited("concert-1")
        #expect(result)
    }

    @Test("setFavorite false removes the favorite")
    func setFavoriteFalse() async throws {
        let repo = makeRepo()
        try await repo.setFavorite(makeSnapshot(), isFavorite: true)
        try await repo.setFavorite(makeSnapshot(), isFavorite: false)
        let result = await repo.isFavorited("concert-1")
        #expect(!result)
    }

    @Test("favoritedConcerts returns snapshot with correct fields")
    func favoritedConcertsFields() async throws {
        let repo = makeRepo()
        let snap = makeSnapshot()
        try await repo.setFavorite(snap, isFavorite: true)
        let favorites = await repo.favoritedConcerts()
        #expect(favorites.count == 1)
        let got = try #require(favorites.first)
        #expect(got.id == snap.id)
        #expect(got.artist == snap.artist)
        #expect(got.date == snap.date)
        #expect(got.venue == snap.venue)
        #expect(got.location == snap.location)
    }

    @Test("favoritedConcerts is empty after removing favorite")
    func favoritedConcertsEmptyAfterRemove() async throws {
        let repo = makeRepo()
        try await repo.setFavorite(makeSnapshot(), isFavorite: true)
        try await repo.setFavorite(makeSnapshot(), isFavorite: false)
        let favorites = await repo.favoritedConcerts()
        #expect(favorites.isEmpty)
    }

    @Test("setFavorite true twice does not duplicate entries")
    func idempotentFavorite() async throws {
        let repo = makeRepo()
        try await repo.setFavorite(makeSnapshot(), isFavorite: true)
        try await repo.setFavorite(makeSnapshot(), isFavorite: true)
        let favorites = await repo.favoritedConcerts()
        #expect(favorites.count == 1)
    }

    @Test("Multiple concerts can be favorited independently")
    func multipleFavorites() async throws {
        let repo = makeRepo()
        try await repo.setFavorite(makeSnapshot(id: "c1"), isFavorite: true)
        try await repo.setFavorite(makeSnapshot(id: "c2"), isFavorite: true)
        let favorites = await repo.favoritedConcerts()
        #expect(favorites.count == 2)
        #expect(await repo.isFavorited("c1"))
        #expect(await repo.isFavorited("c2"))
    }

    @Test("Removing one favorite does not affect others")
    func removingOneFavoritePreservesOthers() async throws {
        let repo = makeRepo()
        try await repo.setFavorite(makeSnapshot(id: "c1"), isFavorite: true)
        try await repo.setFavorite(makeSnapshot(id: "c2"), isFavorite: true)
        try await repo.setFavorite(makeSnapshot(id: "c1"), isFavorite: false)
        let favorites = await repo.favoritedConcerts()
        #expect(favorites.count == 1)
        #expect(favorites.first?.id == "c2")
    }

    @Test("tagItem and items(for:) round-trip via base protocol")
    func tagItemRoundTrip() async throws {
        let repo = makeRepo()
        try await repo.tagItem("item-42", with: Tag.favoriteTagID)
        let items = await repo.items(for: Tag.favoriteTagID)
        #expect(items.contains { $0.itemID == "item-42" })
    }

    @Test("untagItem removes item from tag")
    func untagItemRemoves() async throws {
        let repo = makeRepo()
        try await repo.tagItem("item-42", with: Tag.favoriteTagID)
        try await repo.untagItem("item-42", from: Tag.favoriteTagID)
        let items = await repo.items(for: Tag.favoriteTagID)
        #expect(!items.contains { $0.itemID == "item-42" })
    }

    // MARK: - Playlist integration tests

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

    @Test("createPlaylist produces playlist-kind tag persisted in DB")
    func createPlaylistPersisted() async throws {
        let repo = makeRepo()
        let tag = try await repo.createPlaylist(name: "Faves")
        let tags = await repo.playlistTags()
        #expect(tags.contains { $0.id == tag.id && $0.name == "Faves" })
    }

    @Test("addToPlaylist and playlistItems round-trip in sort order")
    func addAndRetrieveSQLite() async throws {
        let repo = makeRepo()
        let tag = try await repo.createPlaylist(name: "Mix")
        try await repo.addToPlaylist(id: tag.id, items: [
            makePlaylistItem(sortOrder: 0),
            makePlaylistItem(sortOrder: 1)
        ])
        let items = await repo.playlistItems(for: tag.id)
        #expect(items.count == 2)
        #expect(items[0].trackFilename == "track0.flac")
        #expect(items[1].trackFilename == "track1.flac")
    }

    @Test("removeFromPlaylist removes row and renumbers sort_orders")
    func removeFromPlaylistSQLite() async throws {
        let repo = makeRepo()
        let tag = try await repo.createPlaylist(name: "Mix")
        try await repo.addToPlaylist(id: tag.id, items: [
            makePlaylistItem(sortOrder: 0),
            makePlaylistItem(sortOrder: 1),
            makePlaylistItem(sortOrder: 2)
        ])
        var items = await repo.playlistItems(for: tag.id)
        try await repo.removeFromPlaylist(id: tag.id, at: items[1].sortOrder)
        items = await repo.playlistItems(for: tag.id)
        #expect(items.count == 2)
        #expect(items[0].sortOrder == 0)
        #expect(items[1].sortOrder == 1)
    }

    @Test("moveInPlaylist reorders tracks in DB")
    func moveInPlaylistSQLite() async throws {
        let repo = makeRepo()
        let tag = try await repo.createPlaylist(name: "Mix")
        try await repo.addToPlaylist(id: tag.id, items: [
            makePlaylistItem(sortOrder: 0),
            makePlaylistItem(sortOrder: 1),
            makePlaylistItem(sortOrder: 2)
        ])
        var items = await repo.playlistItems(for: tag.id)
        let lastName = items[2].trackFilename
        try await repo.moveInPlaylist(id: tag.id, from: 2, to: 0)
        items = await repo.playlistItems(for: tag.id)
        #expect(items[0].trackFilename == lastName)
    }

    @Test("deletePlaylist removes tag and all playlist_items")
    func deletePlaylistSQLite() async throws {
        let repo = makeRepo()
        let tag = try await repo.createPlaylist(name: "Temp")
        try await repo.addToPlaylist(id: tag.id, items: [makePlaylistItem()])
        try await repo.deletePlaylist(id: tag.id)
        let tags = await repo.playlistTags()
        #expect(!tags.contains { $0.id == tag.id })
        let items = await repo.playlistItems(for: tag.id)
        #expect(items.isEmpty)
    }

    @Test("renamePlaylist updates name in DB")
    func renamePlaylistSQLite() async throws {
        let repo = makeRepo()
        let tag = try await repo.createPlaylist(name: "Before")
        try await repo.renamePlaylist(id: tag.id, name: "After")
        let tags = await repo.playlistTags()
        #expect(tags.first { $0.id == tag.id }?.name == "After")
    }

    @Test("addToPlaylist appends after existing items")
    func addToPlaylistAppends() async throws {
        let repo = makeRepo()
        let tag = try await repo.createPlaylist(name: "Mix")
        try await repo.addToPlaylist(id: tag.id, items: [makePlaylistItem(sortOrder: 0)])
        try await repo.addToPlaylist(id: tag.id, items: [makePlaylistItem(sortOrder: 1)])
        let items = await repo.playlistItems(for: tag.id)
        #expect(items.count == 2)
        #expect(items[0].sortOrder == 0)
        #expect(items[1].sortOrder == 1)
    }
}
