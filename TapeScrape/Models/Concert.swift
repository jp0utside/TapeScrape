import Foundation

struct ArtistMatch: Codable, Hashable {
    let canonicalArtist: String
    let displayArtist: String
    let recordingCount: Int
}

struct ArtistSearchResponse: Codable {
    let query: String
    let type: String
    let matches: [ArtistMatch]
}

struct ConcertListItem: Codable, Hashable {
    let id: String
    let displayArtist: String
    let date: String
    let datePrecision: String
    let displayVenue: String?
    let location: String?
    let recordingCount: Int
    let preferredRecordingId: String
}

struct ConcertListResponse: Codable {
    let concerts: [ConcertListItem]
    let total: Int
    let page: Int
    let pageSize: Int
}

struct ConcertDetailResponse: Codable {
    let id: String
    let artist: String
    let date: String
    let venue: String?
    let location: String?
    let preferredRecordingId: String
    let recordings: [RecordingResponse]
}

struct RecordingResponse: Codable {
    let identifier: String
    let sourceQuality: String
    let source: String?
    let taper: String?
    let lineage: String?
    let downloadCount: Int
    let tracks: [TrackResponse]
}

struct TrackResponse: Codable {
    let index: Int
    let title: String?
    let filename: String
    let duration: String?
    let streamUrl: String
}

extension TrackResponse {
    /// Parse IA duration string ("312.02" or "5:12") to seconds.
    var durationSeconds: TimeInterval? {
        guard let raw = duration else { return nil }
        if let secs = Double(raw) { return secs }
        let parts = raw.split(separator: ":")
        if parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) {
            return m * 60 + s
        }
        return nil
    }
}

struct TrackMatch: Codable, Hashable, Identifiable {
    var id: String { "\(recordingIdentifier)/\(filename)" }
    let title: String?
    let filename: String
    let duration: String?
    let streamUrl: String
    let recordingIdentifier: String
    let concertId: String
    let artist: String
    let date: String
    let venue: String?
    let sourceQuality: String
}

struct TrackSearchResponse: Codable {
    let query: String
    let type: String
    let results: [TrackMatch]
    let total: Int
}
