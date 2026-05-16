import Foundation

protocol AudioStorage {
    func url(for identifier: String, file: String) -> URL?
    func store(_ data: Data, identifier: String, file: String) throws
    func delete(identifier: String, file: String) throws
    func usage() throws -> UInt64
}

struct DocumentsAudioStorage: AudioStorage {
    let root: URL

    init(root: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Recordings")) {
        self.root = root
    }

    func url(for identifier: String, file: String) -> URL? {
        root.appendingPathComponent(identifier).appendingPathComponent(file)
    }

    func store(_ data: Data, identifier: String, file: String) throws {
        let dir = root.appendingPathComponent(identifier)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: dir.appendingPathComponent(file))
    }

    func delete(identifier: String, file: String) throws {
        guard let target = url(for: identifier, file: file) else { return }
        try FileManager.default.removeItem(at: target)
    }

    func usage() throws -> UInt64 {
        guard FileManager.default.fileExists(atPath: root.path) else { return 0 }
        var total: UInt64 = 0
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        )
        while let fileURL = enumerator?.nextObject() as? URL {
            let attrs = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            total += UInt64(attrs.fileSize ?? 0)
        }
        return total
    }
}
