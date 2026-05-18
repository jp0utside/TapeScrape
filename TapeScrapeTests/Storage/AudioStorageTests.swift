import Testing
import Foundation
@testable import TapeScrape

struct AudioStorageTests {
    private func tempStorage() -> DocumentsAudioStorage {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return DocumentsAudioStorage(root: dir)
    }

    @Test func storeAndRetrieve() throws {
        let storage = tempStorage()
        defer { try? FileManager.default.removeItem(at: storage.root) }

        let data = Data("hello tapescrape".utf8)
        try storage.store(data, identifier: "gd1977-05-08.sbd", file: "track01.mp3")

        let url = try #require(storage.url(for: "gd1977-05-08.sbd", file: "track01.mp3"))
        let retrieved = try Data(contentsOf: url)
        #expect(retrieved == data)
    }

    @Test func deleteRemovesFile() throws {
        let storage = tempStorage()
        defer { try? FileManager.default.removeItem(at: storage.root) }

        try storage.store(Data("x".utf8), identifier: "gd1977-05-08.sbd", file: "track01.mp3")
        try storage.delete(identifier: "gd1977-05-08.sbd", file: "track01.mp3")

        let url = try #require(storage.url(for: "gd1977-05-08.sbd", file: "track01.mp3"))
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func usageIsZeroWhenEmpty() throws {
        let storage = tempStorage()
        #expect(try storage.usage() == 0)
    }

    @Test func usageReflectsStoredBytes() throws {
        let storage = tempStorage()
        defer { try? FileManager.default.removeItem(at: storage.root) }

        let data = Data(repeating: 0xAB, count: 256)
        try storage.store(data, identifier: "gd1977-05-08.sbd", file: "track01.mp3")

        #expect(try storage.usage() == 256)
    }

    @Test func fileExistsReturnsTrueAfterStore() throws {
        let storage = tempStorage()
        defer { try? FileManager.default.removeItem(at: storage.root) }

        #expect(!storage.fileExists(identifier: "gd1977-05-08.sbd", file: "track01.mp3"))
        try storage.store(Data("x".utf8), identifier: "gd1977-05-08.sbd", file: "track01.mp3")
        #expect(storage.fileExists(identifier: "gd1977-05-08.sbd", file: "track01.mp3"))
    }

    @Test func fileExistsReturnsFalseAfterDelete() throws {
        let storage = tempStorage()
        defer { try? FileManager.default.removeItem(at: storage.root) }

        try storage.store(Data("x".utf8), identifier: "gd1977-05-08.sbd", file: "track01.mp3")
        try storage.delete(identifier: "gd1977-05-08.sbd", file: "track01.mp3")
        #expect(!storage.fileExists(identifier: "gd1977-05-08.sbd", file: "track01.mp3"))
    }

    @Test func deleteRecordingRemovesDirectory() throws {
        let storage = tempStorage()
        defer { try? FileManager.default.removeItem(at: storage.root) }

        try storage.store(Data("a".utf8), identifier: "gd1977-05-08.sbd", file: "track01.mp3")
        try storage.store(Data("b".utf8), identifier: "gd1977-05-08.sbd", file: "track02.mp3")
        try storage.deleteRecording(identifier: "gd1977-05-08.sbd")

        #expect(!storage.fileExists(identifier: "gd1977-05-08.sbd", file: "track01.mp3"))
        #expect(!storage.fileExists(identifier: "gd1977-05-08.sbd", file: "track02.mp3"))
        let dir = storage.root.appendingPathComponent("gd1977-05-08.sbd")
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }

    @Test func deleteRecordingNoopsWhenMissing() throws {
        let storage = tempStorage()
        #expect(throws: Never.self) {
            try storage.deleteRecording(identifier: "nonexistent")
        }
    }
}
