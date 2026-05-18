import Foundation
import SwiftUI

// Minimal concert metadata stored client-side so LibraryTab can show favorites
// without a network call. Written when the user hearts a concert.
struct ConcertSnapshot: Identifiable, Hashable {
    let id: String        // concert UUID from the backend
    let artist: String
    let date: String
    let venue: String?
    let location: String?
}

protocol LibraryRepository: Sendable {
    func tags() async -> [Tag]
    func addTag(_ tag: Tag) async throws
    func removeTag(_ id: Tag.ID) async throws
    func items(for tagID: Tag.ID) async -> [TaggedItem]
    func tagItem(_ itemID: String, with tagID: Tag.ID) async throws
    func untagItem(_ itemID: String, from tagID: Tag.ID) async throws

    // Favorites convenience — backed by the system "favorite" tag + concert snapshots.
    func isFavorited(_ itemID: String) async -> Bool
    func favoritedConcerts() async -> [ConcertSnapshot]
    func setFavorite(_ snapshot: ConcertSnapshot, isFavorite: Bool) async throws

    // Playlists
    func createPlaylist(name: String) async throws -> Tag
    func deletePlaylist(id: Tag.ID) async throws
    func renamePlaylist(id: Tag.ID, name: String) async throws
    func playlistTags() async -> [Tag]
    func playlistItems(for playlistID: Tag.ID) async -> [PlaylistItem]
    func addToPlaylist(id: Tag.ID, items: [PlaylistItem]) async throws
    func removeFromPlaylist(id: Tag.ID, at sortOrder: Int) async throws
    func moveInPlaylist(id: Tag.ID, from: Int, to: Int) async throws
}

// EnvironmentKey so views can read the repo without threading it through every init.
// Default falls back to InMemoryLibraryRepository so previews and tests work.
private struct LibraryRepositoryKey: EnvironmentKey {
    static let defaultValue: any LibraryRepository = InMemoryLibraryRepository()
}

extension EnvironmentValues {
    var libraryRepository: any LibraryRepository {
        get { self[LibraryRepositoryKey.self] }
        set { self[LibraryRepositoryKey.self] = newValue }
    }
}

actor InMemoryLibraryRepository: LibraryRepository {
    private var storedTags: [Tag] = [.favoriteTag]
    private var taggings: [TaggedItem] = []
    private var snapshots: [String: ConcertSnapshot] = [:]
    private var storedPlaylistItems: [Tag.ID: [PlaylistItem]] = [:]

    func tags() async -> [Tag] {
        storedTags
    }

    func addTag(_ tag: Tag) async throws {
        storedTags.append(tag)
    }

    func removeTag(_ id: Tag.ID) async throws {
        storedTags.removeAll { $0.id == id }
        taggings.removeAll { $0.tagID == id }
    }

    func items(for tagID: Tag.ID) async -> [TaggedItem] {
        taggings.filter { $0.tagID == tagID }
    }

    func tagItem(_ itemID: String, with tagID: Tag.ID) async throws {
        guard !taggings.contains(where: { $0.tagID == tagID && $0.itemID == itemID }) else { return }
        taggings.append(TaggedItem(tagID: tagID, itemID: itemID))
    }

    func untagItem(_ itemID: String, from tagID: Tag.ID) async throws {
        taggings.removeAll { $0.tagID == tagID && $0.itemID == itemID }
    }

    func isFavorited(_ itemID: String) async -> Bool {
        taggings.contains { $0.tagID == Tag.favoriteTagID && $0.itemID == itemID }
    }

    func favoritedConcerts() async -> [ConcertSnapshot] {
        let favoritedIDs = taggings
            .filter { $0.tagID == Tag.favoriteTagID }
            .map(\.itemID)
        return favoritedIDs.compactMap { snapshots[$0] }
    }

    func setFavorite(_ snapshot: ConcertSnapshot, isFavorite: Bool) async throws {
        if isFavorite {
            snapshots[snapshot.id] = snapshot
            if !taggings.contains(where: { $0.tagID == Tag.favoriteTagID && $0.itemID == snapshot.id }) {
                taggings.append(TaggedItem(tagID: Tag.favoriteTagID, itemID: snapshot.id))
            }
        } else {
            taggings.removeAll { $0.tagID == Tag.favoriteTagID && $0.itemID == snapshot.id }
        }
    }

    // MARK: - Playlists

    func createPlaylist(name: String) async throws -> Tag {
        let tag = Tag(id: UUID(), name: name, kind: .playlist)
        storedTags.append(tag)
        storedPlaylistItems[tag.id] = []
        return tag
    }

    func deletePlaylist(id: Tag.ID) async throws {
        storedTags.removeAll { $0.id == id }
        storedPlaylistItems.removeValue(forKey: id)
    }

    func renamePlaylist(id: Tag.ID, name: String) async throws {
        if let idx = storedTags.firstIndex(where: { $0.id == id }) {
            storedTags[idx].name = name
        }
    }

    func playlistTags() async -> [Tag] {
        storedTags.filter { $0.kind == .playlist }
    }

    func playlistItems(for playlistID: Tag.ID) async -> [PlaylistItem] {
        (storedPlaylistItems[playlistID] ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    func addToPlaylist(id: Tag.ID, items: [PlaylistItem]) async throws {
        var existing = storedPlaylistItems[id] ?? []
        let nextSort = (existing.map(\.sortOrder).max() ?? -1) + 1
        let newItems = items.enumerated().map { offset, item in
            PlaylistItem(
                id: item.id,
                recordingIdentifier: item.recordingIdentifier,
                trackFilename: item.trackFilename,
                streamURL: item.streamURL,
                trackTitle: item.trackTitle,
                trackDuration: item.trackDuration,
                trackIndex: item.trackIndex,
                sortOrder: nextSort + offset,
                concertID: item.concertID,
                artist: item.artist,
                date: item.date,
                venue: item.venue
            )
        }
        existing.append(contentsOf: newItems)
        storedPlaylistItems[id] = existing
    }

    func removeFromPlaylist(id: Tag.ID, at sortOrder: Int) async throws {
        guard var items = storedPlaylistItems[id] else { return }
        items.removeAll { $0.sortOrder == sortOrder }
        storedPlaylistItems[id] = renumbered(items)
    }

    func moveInPlaylist(id: Tag.ID, from: Int, to: Int) async throws {
        guard var items = storedPlaylistItems[id], from < items.count else { return }
        items.sort { $0.sortOrder < $1.sortOrder }
        items.move(fromOffsets: IndexSet(integer: from), toOffset: to)
        storedPlaylistItems[id] = renumbered(items)
    }

    private func renumbered(_ items: [PlaylistItem]) -> [PlaylistItem] {
        items.enumerated().map { idx, item in
            PlaylistItem(
                id: item.id,
                recordingIdentifier: item.recordingIdentifier,
                trackFilename: item.trackFilename,
                streamURL: item.streamURL,
                trackTitle: item.trackTitle,
                trackDuration: item.trackDuration,
                trackIndex: item.trackIndex,
                sortOrder: idx,
                concertID: item.concertID,
                artist: item.artist,
                date: item.date,
                venue: item.venue
            )
        }
    }
}
