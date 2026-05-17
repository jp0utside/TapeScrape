import Testing
import Foundation
@testable import TapeScrape

struct CatalogClientTests {
    // Fixture JSON matching the real backend response shape for gd-1977-05-08.
    private let fixtureJSON = """
    {
        "id": "gd-1977-05-08",
        "artist": "Grateful Dead",
        "date": "1977-05-08",
        "venue": "Barton Hall - Cornell University",
        "location": "Ithaca, NY",
        "preferred_recording_id": "gd1977-05-08.aud.moore.berger.28354.flac16",
        "recordings": [
            {
                "identifier": "gd1977-05-08.aud.moore.berger.28354.flac16",
                "source": "MAC>R>CD",
                "taper": null,
                "lineage": "",
                "download_count": 560753,
                "tracks": [
                    {
                        "index": 0,
                        "title": "New Minglewood Blues",
                        "filename": "gd77-05-08.aud.moore.d1t01.flac",
                        "duration": "312.02",
                        "stream_url": "https://archive.org/download/gd1977-05-08.aud.moore.berger.28354.flac16/gd77-05-08.aud.moore.d1t01.flac"
                    },
                    {
                        "index": 1,
                        "title": null,
                        "filename": "gd77-05-08.aud.moore.d1t02.flac",
                        "duration": "454.7",
                        "stream_url": "https://archive.org/download/gd1977-05-08.aud.moore.berger.28354.flac16/gd77-05-08.aud.moore.d1t02.flac"
                    }
                ]
            }
        ]
    }
    """

    private func decode() throws -> ConcertResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ConcertResponse.self, from: Data(fixtureJSON.utf8))
    }

    @Test func decodesTopLevelFields() throws {
        let concert = try decode()
        #expect(concert.id == "gd-1977-05-08")
        #expect(concert.artist == "Grateful Dead")
        #expect(concert.date == "1977-05-08")
        #expect(concert.venue == "Barton Hall - Cornell University")
        #expect(concert.location == "Ithaca, NY")
    }

    @Test func decodesSnakeCasePreferredRecordingId() throws {
        let concert = try decode()
        #expect(concert.preferredRecordingId == "gd1977-05-08.aud.moore.berger.28354.flac16")
    }

    @Test func decodesRecordings() throws {
        let concert = try decode()
        #expect(concert.recordings.count == 1)
        let rec = concert.recordings[0]
        #expect(rec.identifier == "gd1977-05-08.aud.moore.berger.28354.flac16")
        #expect(rec.source == "MAC>R>CD")
        #expect(rec.taper == nil)
        #expect(rec.downloadCount == 560753)
    }

    @Test func decodesTracks() throws {
        let concert = try decode()
        let tracks = concert.recordings[0].tracks
        #expect(tracks.count == 2)
        #expect(tracks[0].index == 0)
        #expect(tracks[0].title == "New Minglewood Blues")
        #expect(tracks[0].filename == "gd77-05-08.aud.moore.d1t01.flac")
        #expect(tracks[0].duration == "312.02")
    }

    @Test func tracksHaveOpaqueStreamURLs() throws {
        let concert = try decode()
        for track in concert.recordings[0].tracks {
            #expect(track.streamUrl.hasPrefix("https://archive.org/download/"))
            #expect(track.streamUrl.hasSuffix(track.filename))
        }
    }

    @Test func decodesOptionalTitleAsNil() throws {
        let concert = try decode()
        #expect(concert.recordings[0].tracks[1].title == nil)
    }
}
