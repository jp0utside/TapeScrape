"""Tests for the aggregation persistence layer — round-trip read/write."""

import time
from pathlib import Path

import pytest

from backend.aggregation.aggregate import (
    AggregatedConcert,
    AggregatedRecording,
    AggregatedTrack,
)
from backend.aggregation.source_quality import SourceQuality
from backend.db.repository import (
    get_aggregation_age,
    get_concert_by_id,
    get_concerts_for_artist,
    save_aggregation,
)


@pytest.fixture
def db_path(tmp_path: Path) -> Path:
    return tmp_path / "test.db"


def _sample_concert(
    concert_id: str = "test-uuid-1234",
    canonical_artist: str = "grateful dead",
    date: str = "1977-05-08",
) -> AggregatedConcert:
    return AggregatedConcert(
        id=concert_id,
        canonical_artist=canonical_artist,
        display_artist="Grateful Dead",
        date=date,
        date_precision="day",
        canonical_venue="barton hall",
        display_venue="Barton Hall",
        location="Ithaca, NY",
        recordings=[
            AggregatedRecording(
                identifier="gd1977-05-08.sbd.miller.12345",
                source_quality=SourceQuality.SBD,
                source="SBD > Master Reel",
                taper="Jack Miller",
                lineage="Master Reel > DAT > CD",
                downloads=500,
                tracks=[
                    AggregatedTrack(
                        index=0,
                        title="Promised Land",
                        filename="track01.flac",
                        duration="5:30",
                        size="20000000",
                        stream_url="https://archive.org/download/gd1977-05-08.sbd.miller.12345/track01.flac",
                    ),
                    AggregatedTrack(
                        index=1,
                        title="Sugaree",
                        filename="track02.flac",
                        duration="9:43",
                        size="37000000",
                        stream_url="https://archive.org/download/gd1977-05-08.sbd.miller.12345/track02.flac",
                    ),
                ],
            ),
            AggregatedRecording(
                identifier="gd1977-05-08.aud.jones.67890",
                source_quality=SourceQuality.AUD,
                source="AUD > DAT",
                taper="Bob Jones",
                lineage=None,
                downloads=100,
                tracks=[],
            ),
        ],
        preferred_recording_id="gd1977-05-08.sbd.miller.12345",
        aggregated_at=time.time(),
    )


class TestSaveAndLoad:
    def test_round_trip(self, db_path: Path):
        concert = _sample_concert()
        save_aggregation(db_path, [concert])

        loaded = get_concerts_for_artist(db_path, "grateful dead")

        assert len(loaded) == 1
        c = loaded[0]
        assert c.id == concert.id
        assert c.canonical_artist == "grateful dead"
        assert c.display_artist == "Grateful Dead"
        assert c.date == "1977-05-08"
        assert c.date_precision == "day"
        assert c.canonical_venue == "barton hall"
        assert c.display_venue == "Barton Hall"
        assert c.location == "Ithaca, NY"
        assert c.preferred_recording_id == "gd1977-05-08.sbd.miller.12345"
        assert len(c.recordings) == 2

    def test_recordings_preserved(self, db_path: Path):
        concert = _sample_concert()
        save_aggregation(db_path, [concert])

        loaded = get_concerts_for_artist(db_path, "grateful dead")
        rec = loaded[0].recordings[0]

        assert rec.identifier == "gd1977-05-08.sbd.miller.12345"
        assert rec.source_quality == SourceQuality.SBD
        assert rec.source == "SBD > Master Reel"
        assert rec.taper == "Jack Miller"
        assert rec.lineage == "Master Reel > DAT > CD"
        assert rec.downloads == 500

    def test_tracks_preserved(self, db_path: Path):
        concert = _sample_concert()
        save_aggregation(db_path, [concert])

        loaded = get_concerts_for_artist(db_path, "grateful dead")
        tracks = loaded[0].recordings[0].tracks

        assert len(tracks) == 2
        assert tracks[0].title == "Promised Land"
        assert tracks[0].filename == "track01.flac"
        assert tracks[0].duration == "5:30"
        assert tracks[0].stream_url == "https://archive.org/download/gd1977-05-08.sbd.miller.12345/track01.flac"
        assert tracks[1].title == "Sugaree"

    def test_resave_replaces_cleanly(self, db_path: Path):
        concert = _sample_concert()
        save_aggregation(db_path, [concert])

        # Resave with different data
        updated = _sample_concert(date="1977-05-09")
        save_aggregation(db_path, [updated])

        loaded = get_concerts_for_artist(db_path, "grateful dead")
        assert len(loaded) == 1
        assert loaded[0].date == "1977-05-09"

    def test_different_artists_independent(self, db_path: Path):
        gd = _sample_concert(concert_id="gd-id", canonical_artist="grateful dead")
        phish = _sample_concert(concert_id="phish-id", canonical_artist="phish")
        phish.display_artist = "Phish"
        # Different recording identifiers to avoid UNIQUE constraint
        phish.recordings[0].identifier = "phish1997-12-31.sbd.12345"
        phish.recordings[0].tracks[0].stream_url = "https://archive.org/download/phish1997-12-31.sbd.12345/track01.flac"
        phish.recordings[0].tracks[1].stream_url = "https://archive.org/download/phish1997-12-31.sbd.12345/track02.flac"
        phish.recordings[1].identifier = "phish1997-12-31.aud.67890"
        phish.preferred_recording_id = "phish1997-12-31.sbd.12345"

        save_aggregation(db_path, [gd])
        save_aggregation(db_path, [phish])

        gd_loaded = get_concerts_for_artist(db_path, "grateful dead")
        phish_loaded = get_concerts_for_artist(db_path, "phish")

        assert len(gd_loaded) == 1
        assert len(phish_loaded) == 1


class TestGetConcertById:
    def test_found(self, db_path: Path):
        concert = _sample_concert()
        save_aggregation(db_path, [concert])

        loaded = get_concert_by_id(db_path, concert.id)
        assert loaded is not None
        assert loaded.id == concert.id
        assert len(loaded.recordings) == 2

    def test_not_found(self, db_path: Path):
        assert get_concert_by_id(db_path, "nonexistent") is None


class TestAggregationAge:
    def test_returns_age_in_seconds(self, db_path: Path):
        concert = _sample_concert()
        concert.aggregated_at = time.time() - 60  # 1 minute ago
        save_aggregation(db_path, [concert])

        age = get_aggregation_age(db_path, "grateful dead")
        assert age is not None
        assert 59 <= age <= 62

    def test_never_aggregated(self, db_path: Path):
        assert get_aggregation_age(db_path, "grateful dead") is None

    def test_different_artist_returns_none(self, db_path: Path):
        concert = _sample_concert()
        save_aggregation(db_path, [concert])

        assert get_aggregation_age(db_path, "phish") is None
