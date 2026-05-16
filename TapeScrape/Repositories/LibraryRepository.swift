import Foundation

protocol LibraryRepository {
    func tags() async -> [Tag]
    func addTag(_ tag: Tag) async throws
    func removeTag(_ id: Tag.ID) async throws
    func items(for tagID: Tag.ID) async -> [TaggedItem]
    func tagItem(_ itemID: String, with tagID: Tag.ID) async throws
    func untagItem(_ itemID: String, from tagID: Tag.ID) async throws
}

actor InMemoryLibraryRepository: LibraryRepository {
    private var storedTags: [Tag] = []
    private var taggings: [TaggedItem] = []

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
}
