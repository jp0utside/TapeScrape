import Testing
import Foundation
@testable import TapeScrape

struct CatalogClientTests {

    // MARK: - ConcertDetailResponse

    private let concertDetailJSON = """
    {
        "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
        "artist": "Grateful Dead",
        "date": "1977-05-08",
        "venue": "Barton Hall - Cornell University",
        "location": "Ithaca, NY",
        "preferred_recording_id": "gd1977-05-08.aud.moore.berger.28354.flac16",
        "recordings": [
            {
                "identifier": "gd1977-05-08.aud.moore.berger.28354.flac16",
                "source_quality": "AUD",
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

    private func decodeDetail() throws -> ConcertDetailResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ConcertDetailResponse.self, from: Data(concertDetailJSON.utf8))
    }

    @Test func decodesTopLevelFields() throws {
        let concert = try decodeDetail()
        #expect(concert.id == "a1b2c3d4-e5f6-7890-abcd-ef1234567890")
        #expect(concert.artist == "Grateful Dead")
        #expect(concert.date == "1977-05-08")
        #expect(concert.venue == "Barton Hall - Cornell University")
        #expect(concert.location == "Ithaca, NY")
    }

    @Test func decodesSnakeCasePreferredRecordingId() throws {
        let concert = try decodeDetail()
        #expect(concert.preferredRecordingId == "gd1977-05-08.aud.moore.berger.28354.flac16")
    }

    @Test func decodesRecordings() throws {
        let concert = try decodeDetail()
        #expect(concert.recordings.count == 1)
        let rec = concert.recordings[0]
        #expect(rec.identifier == "gd1977-05-08.aud.moore.berger.28354.flac16")
        #expect(rec.source == "MAC>R>CD")
        #expect(rec.taper == nil)
        #expect(rec.sourceQuality == "AUD")
        #expect(rec.downloadCount == 560753)
    }

    @Test func decodesTracks() throws {
        let concert = try decodeDetail()
        let tracks = concert.recordings[0].tracks
        #expect(tracks.count == 2)
        #expect(tracks[0].index == 0)
        #expect(tracks[0].title == "New Minglewood Blues")
        #expect(tracks[0].filename == "gd77-05-08.aud.moore.d1t01.flac")
        #expect(tracks[0].duration == "312.02")
    }

    @Test func tracksHaveOpaqueStreamURLs() throws {
        let concert = try decodeDetail()
        for track in concert.recordings[0].tracks {
            #expect(track.streamUrl.hasPrefix("https://archive.org/download/"))
            #expect(track.streamUrl.hasSuffix(track.filename))
        }
    }

    @Test func decodesOptionalTitleAsNil() throws {
        let concert = try decodeDetail()
        #expect(concert.recordings[0].tracks[1].title == nil)
    }

    // MARK: - ArtistSearchResponse

    private let artistSearchJSON = """
    {
        "query": "grateful dead",
        "type": "artist",
        "matches": [
            {
                "canonical_artist": "grateful dead",
                "display_artist": "Grateful Dead",
                "recording_count": 47
            },
            {
                "canonical_artist": "jerry garcia band",
                "display_artist": "Jerry Garcia Band",
                "recording_count": 12
            }
        ]
    }
    """

    @Test func decodesArtistSearchResponse() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ArtistSearchResponse.self, from: Data(artistSearchJSON.utf8))
        #expect(response.query == "grateful dead")
        #expect(response.type == "artist")
        #expect(response.matches.count == 2)
    }

    @Test func decodesArtistMatchFields() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ArtistSearchResponse.self, from: Data(artistSearchJSON.utf8))
        let first = response.matches[0]
        #expect(first.canonicalArtist == "grateful dead")
        #expect(first.displayArtist == "Grateful Dead")
        #expect(first.recordingCount == 47)
    }

    // MARK: - ConcertListResponse

    private let concertListJSON = """
    {
        "concerts": [
            {
                "id": "abc-123",
                "display_artist": "Grateful Dead",
                "date": "1977-05-08",
                "date_precision": "day",
                "display_venue": "Barton Hall",
                "location": "Ithaca, NY",
                "recording_count": 3,
                "preferred_recording_id": "gd77-sbd-abc"
            },
            {
                "id": "def-456",
                "display_artist": "Grateful Dead",
                "date": "1977-05-09",
                "date_precision": "day",
                "display_venue": null,
                "location": null,
                "recording_count": 1,
                "preferred_recording_id": "gd77-aud-def"
            }
        ],
        "total": 50,
        "page": 1,
        "page_size": 20
    }
    """

    @Test func decodesConcertListResponse() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ConcertListResponse.self, from: Data(concertListJSON.utf8))
        #expect(response.total == 50)
        #expect(response.page == 1)
        #expect(response.pageSize == 20)
        #expect(response.concerts.count == 2)
    }

    @Test func decodesConcertListItemFields() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ConcertListResponse.self, from: Data(concertListJSON.utf8))
        let item = response.concerts[0]
        #expect(item.id == "abc-123")
        #expect(item.displayArtist == "Grateful Dead")
        #expect(item.date == "1977-05-08")
        #expect(item.datePrecision == "day")
        #expect(item.displayVenue == "Barton Hall")
        #expect(item.location == "Ithaca, NY")
        #expect(item.recordingCount == 3)
        #expect(item.preferredRecordingId == "gd77-sbd-abc")
    }

    @Test func decodesNullOptionalVenueAndLocation() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ConcertListResponse.self, from: Data(concertListJSON.utf8))
        let item = response.concerts[1]
        #expect(item.displayVenue == nil)
        #expect(item.location == nil)
    }
}
