import Foundation

struct Tag: Identifiable, Codable {
    let id: UUID
    var name: String
    var kind: TagKind
}

enum TagKind: String, Codable {
    case favorite, playlist, smart, user
}

struct TaggedItem: Identifiable {
    var id: String { "\(tagID):\(itemID)" }
    let tagID: Tag.ID
    let itemID: String
}
