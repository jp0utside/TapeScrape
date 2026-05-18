"""Tests for the core aggregation logic — grouping items into concerts."""


from backend.aggregation.aggregate import (
    aggregate_items,
)
from backend.aggregation.source_quality import SourceQuality
from backend.models.ia import IAItem, IAItemMetadata, IASearchItem


def _make_search_item(
    identifier: str,
    creator: str = "Grateful Dead",
    date: str = "1977-05-08",
    downloads: int = 100,
) -> IASearchItem:
    return IASearchItem(
        identifier=identifier,
        title=f"Live at venue on {date}",
        creator=creator,
        date=date,
        downloads=downloads,
    )


def _make_ia_item(
    identifier: str,
    venue: str | None = "Barton Hall",
    coverage: str | None = "Ithaca, NY",
    source: str | None = "SBD > Master Reel",
    taper: str | None = "Jack Miller",
    files: list[dict] | None = None,
) -> IAItem:
    if files is None:
        files = [
            {"name": "track01.flac", "format": "Flac", "title": "Promised Land", "length": "5:30", "size": "20000000"},
            {"name": "track02.flac", "format": "Flac", "title": "Sugaree", "length": "9:43", "size": "37000000"},
        ]
    return IAItem(
        metadata=IAItemMetadata(
            identifier=identifier,
            title=f"Grateful Dead Live at {venue}",
            creator="Grateful Dead",
            date="1977-05-08",
            venue=venue,
            coverage=coverage,
            source=source,
            taper=taper,
        ),
        files=files,
    )


class TestAggregateItems:
    def test_single_item_produces_one_concert(self):
        items = [_make_search_item("gd1977-05-08.sbd.miller.12345")]
        fetched = {"gd1977-05-08.sbd.miller.12345": _make_ia_item("gd1977-05-08.sbd.miller.12345")}

        concerts = aggregate_items("grateful dead", "Grateful Dead", items, fetched)

        assert len(concerts) == 1
        c = concerts[0]
        assert c.canonical_artist == "grateful dead"
        assert c.display_artist == "Grateful Dead"
        assert c.date == "1977-05-08"
        assert c.date_precision == "day"
        assert c.display_venue == "Barton Hall"
        assert c.location == "Ithaca, NY"
        assert len(c.recordings) == 1
        assert c.preferred_recording_id == "gd1977-05-08.sbd.miller.12345"

    def test_multiple_items_same_concert_grouped(self):
        items = [
            _make_search_item("gd1977-05-08.sbd.miller.12345", downloads=500),
            _make_search_item("gd1977-05-08.aud.jones.67890", downloads=100),
        ]
        fetched = {
            "gd1977-05-08.sbd.miller.12345": _make_ia_item("gd1977-05-08.sbd.miller.12345"),
            "gd1977-05-08.aud.jones.67890": _make_ia_item(
                "gd1977-05-08.aud.jones.67890", source="AUD > DAT"
            ),
        }

        concerts = aggregate_items("grateful dead", "Grateful Dead", items, fetched)

        assert len(concerts) == 1
        c = concerts[0]
        assert len(c.recordings) == 2
        # SBD should be first (better quality)
        assert c.recordings[0].source_quality == SourceQuality.SBD
        assert c.recordings[1].source_quality == SourceQuality.AUD
        assert c.preferred_recording_id == "gd1977-05-08.sbd.miller.12345"

    def test_different_dates_produce_separate_concerts(self):
        items = [
            _make_search_item("gd1977-05-08.12345", date="1977-05-08"),
            _make_search_item("gd1977-05-09.12345", date="1977-05-09"),
        ]
        fetched = {
            "gd1977-05-08.12345": _make_ia_item("gd1977-05-08.12345"),
            "gd1977-05-09.12345": _make_ia_item("gd1977-05-09.12345", venue="Boston Garden", coverage="Boston, MA"),
        }

        concerts = aggregate_items("grateful dead", "Grateful Dead", items, fetched)

        assert len(concerts) == 2
        assert concerts[0].date == "1977-05-08"
        assert concerts[1].date == "1977-05-09"

    def test_two_venues_same_day_produce_two_concerts(self):
        items = [
            _make_search_item("fest-day1-venue1.12345", date="1997-08-16"),
            _make_search_item("fest-day1-venue2.12345", date="1997-08-16"),
        ]
        fetched = {
            "fest-day1-venue1.12345": _make_ia_item(
                "fest-day1-venue1.12345", venue="Main Stage"
            ),
            "fest-day1-venue2.12345": _make_ia_item(
                "fest-day1-venue2.12345", venue="Side Tent"
            ),
        }

        concerts = aggregate_items("phish", "Phish", items, fetched)

        assert len(concerts) == 2

    def test_year_only_date_separate_tier(self):
        items = [
            _make_search_item("gd1977-full.12345", date="1977-05-08"),
            _make_search_item("gd1977-year.12345", date="1977"),
        ]
        fetched = {
            "gd1977-full.12345": _make_ia_item("gd1977-full.12345"),
            "gd1977-year.12345": _make_ia_item("gd1977-year.12345"),
        }

        concerts = aggregate_items("grateful dead", "Grateful Dead", items, fetched)

        day_concerts = [c for c in concerts if c.date_precision == "day"]
        year_concerts = [c for c in concerts if c.date_precision == "year"]
        assert len(day_concerts) == 1
        assert len(year_concerts) == 1
        assert year_concerts[0].date == "1977"

    def test_tracks_built_from_playable_files(self):
        files = [
            {"name": "track01.flac", "format": "Flac", "title": "Song A", "length": "5:30", "size": "20000000"},
            {"name": "track01.ogg", "format": "Ogg Vorbis", "title": "Song A", "length": "5:30", "size": "5000000"},
            {"name": "track02.mp3", "format": "VBR MP3", "title": "Song B", "length": "3:20", "size": "3000000"},
        ]
        items = [_make_search_item("gd.12345")]
        fetched = {"gd.12345": _make_ia_item("gd.12345", files=files)}

        concerts = aggregate_items("grateful dead", "Grateful Dead", items, fetched)

        tracks = concerts[0].recordings[0].tracks
        assert len(tracks) == 2
        assert tracks[0].title == "Song A"
        assert tracks[1].title == "Song B"
        assert "archive.org/download/gd.12345/" in tracks[0].stream_url

    def test_preferred_recording_tiebreak_by_tracks(self):
        """Same quality → more tracks wins."""
        items = [
            _make_search_item("rec-fewer.12345", downloads=200),
            _make_search_item("rec-more.12345", downloads=100),
        ]
        fetched = {
            "rec-fewer.12345": _make_ia_item(
                "rec-fewer.12345",
                source="SBD",
                files=[{"name": "t1.flac", "format": "Flac", "title": "A", "length": "5:00", "size": "1"}],
            ),
            "rec-more.12345": _make_ia_item(
                "rec-more.12345",
                source="SBD",
                files=[
                    {"name": "t1.flac", "format": "Flac", "title": "A", "length": "5:00", "size": "1"},
                    {"name": "t2.flac", "format": "Flac", "title": "B", "length": "5:00", "size": "1"},
                    {"name": "t3.flac", "format": "Flac", "title": "C", "length": "5:00", "size": "1"},
                ],
            ),
        }

        concerts = aggregate_items("grateful dead", "Grateful Dead", items, fetched)
        assert concerts[0].preferred_recording_id == "rec-more.12345"

    def test_preferred_recording_tiebreak_by_downloads(self):
        """Same quality, same track count → most downloads wins."""
        items = [
            _make_search_item("rec-pop.12345", downloads=500),
            _make_search_item("rec-unpop.12345", downloads=50),
        ]
        fetched = {
            "rec-pop.12345": _make_ia_item("rec-pop.12345", source="SBD"),
            "rec-unpop.12345": _make_ia_item("rec-unpop.12345", source="SBD"),
        }

        concerts = aggregate_items("grateful dead", "Grateful Dead", items, fetched)
        assert concerts[0].preferred_recording_id == "rec-pop.12345"

    def test_items_without_metadata_get_unknown_quality(self):
        items = [
            _make_search_item("gd.fetched.12345", downloads=100),
            _make_search_item("gd.unfetched.12345", downloads=50),
        ]
        fetched = {"gd.fetched.12345": _make_ia_item("gd.fetched.12345")}

        concerts = aggregate_items("grateful dead", "Grateful Dead", items, fetched)

        assert len(concerts) == 1
        recs = concerts[0].recordings
        unfetched = [r for r in recs if r.identifier == "gd.unfetched.12345"]
        assert unfetched[0].source_quality == SourceQuality.UNKNOWN
        assert unfetched[0].tracks == []

    def test_concert_id_is_deterministic(self):
        items = [_make_search_item("gd.12345")]
        fetched = {"gd.12345": _make_ia_item("gd.12345")}

        c1 = aggregate_items("grateful dead", "Grateful Dead", items, fetched)
        c2 = aggregate_items("grateful dead", "Grateful Dead", items, fetched)

        assert c1[0].id == c2[0].id

    def test_unparseable_date_skipped(self):
        items = [_make_search_item("gd.bad-date.12345", date="not-a-date")]
        fetched = {}

        concerts = aggregate_items("grateful dead", "Grateful Dead", items, fetched)
        assert concerts == []
