import Foundation

struct ConcertResponse: Codable {
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
