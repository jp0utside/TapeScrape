import Foundation

struct Tag: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var kind: TagKind
}

enum TagKind: String, Codable, Hashable {
    case favorite, playlist, smart, user
}

struct PlaylistItem: Identifiable, Sendable {
    let id: UUID
    let recordingIdentifier: String
    let trackFilename: String
    let streamURL: String
    let trackTitle: String?
    let trackDuration: String?
    let trackIndex: Int
    let sortOrder: Int
    let concertID: String?
    let artist: String?
    let date: String?
    let venue: String?
}

struct TaggedItem: Identifiable {
    var id: String { "\(tagID):\(itemID)" }
    let tagID: Tag.ID
    let itemID: String
}

extension Tag {
    // Stable UUID for the system "favorite" tag — never changes across launches.
    static let favoriteTagID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let favoriteTag = Tag(id: favoriteTagID, name: "Favorites", kind: .favorite)
}
