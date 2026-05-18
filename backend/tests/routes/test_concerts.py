"""Tests for /concerts list and detail endpoints backed by persisted aggregation."""

import time
from pathlib import Path
from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from backend.aggregation.aggregate import AggregatedConcert, AggregatedRecording, AggregatedTrack
from backend.aggregation.source_quality import SourceQuality
from backend.core.cache import MetadataCache
from backend.core.config import settings as real_settings
from backend.db.repository import save_aggregation
from backend.main import app
from backend.routes.deps import get_ia_client, get_metadata_cache

client = TestClient(app)


@pytest.fixture(autouse=True)
def _override_ia_client(request, tmp_path):
    """Inject dummy IAClient and a fresh MetadataCache for non-live tests."""
    if request.node.get_closest_marker("live_ia"):
        yield
        return
    meta_cache = MetadataCache(tmp_path / "meta.db")
    app.dependency_overrides[get_ia_client] = lambda: object()
    app.dependency_overrides[get_metadata_cache] = lambda: meta_cache
    yield
    app.dependency_overrides.pop(get_ia_client, None)
    app.dependency_overrides.pop(get_metadata_cache, None)


# --- Fixtures and helpers ---

def _make_track(recording_id: str, idx: int = 0, title: str = "Song One") -> AggregatedTrack:
    return AggregatedTrack(
        index=idx,
        title=title,
        filename=f"track{idx+1:02d}.flac",
        duration="5:00",
        size="20000000",
        stream_url=f"https://archive.org/download/{recording_id}/track{idx+1:02d}.flac",
    )


def _make_recording(
    identifier: str,
    sq: SourceQuality = SourceQuality.SBD,
    downloads: int = 200,
    num_tracks: int = 1,
) -> AggregatedRecording:
    return AggregatedRecording(
        identifier=identifier,
        source_quality=sq,
        source="SBD > DAT" if sq == SourceQuality.SBD else "AUD > DAT",
        taper="Test Taper",
        lineage="DAT > CD",
        downloads=downloads,
        tracks=[_make_track(identifier, i) for i in range(num_tracks)],
    )


def _make_concert(
    concert_id: str,
    date: str,
    canonical_artist: str = "grateful dead",
    aggregated_at: float | None = None,
    recordings: list[AggregatedRecording] | None = None,
) -> AggregatedConcert:
    if aggregated_at is None:
        aggregated_at = time.time()
    if recordings is None:
        recordings = [_make_recording(f"{concert_id}.sbd")]
    return AggregatedConcert(
        id=concert_id,
        canonical_artist=canonical_artist,
        display_artist="Grateful Dead",
        date=date,
        date_precision="day",
        canonical_venue="barton hall",
        display_venue="Barton Hall",
        location="Ithaca, NY",
        recordings=recordings,
        preferred_recording_id=recordings[0].identifier,
        aggregated_at=aggregated_at,
    )


class _MockSettings:
    """Minimal settings stand-in that points at a temp DB."""

    def __init__(self, db_path: Path):
        self.cache_db_path = db_path
        self.aggregation_staleness_seconds = real_settings.aggregation_staleness_seconds
        self.concerts_page_size = 3  # small page size so pagination tests work with few fixtures


@pytest.fixture
def db_fresh(tmp_path: Path, monkeypatch) -> tuple[Path, list[AggregatedConcert]]:
    """5 concerts with fresh aggregated_at; page_size patched to 3."""
    db = tmp_path / "test.db"
    concerts = [
        _make_concert(f"concert-{i:03d}", f"1977-05-{i+1:02d}", aggregated_at=time.time())
        for i in range(5)
    ]
    save_aggregation(db, concerts)
    mock_settings = _MockSettings(db)
    monkeypatch.setattr("backend.routes.concerts.settings", mock_settings)
    monkeypatch.setattr("backend.aggregation.orchestrate.settings", mock_settings)
    return db, concerts


@pytest.fixture
def db_stale(tmp_path: Path, monkeypatch) -> tuple[Path, list[AggregatedConcert]]:
    """2 concerts with stale aggregated_at (beyond staleness threshold)."""
    db = tmp_path / "test.db"
    stale_time = time.time() - real_settings.aggregation_staleness_seconds - 100
    concerts = [
        _make_concert("stale-001", "1977-05-08", aggregated_at=stale_time),
        _make_concert("stale-002", "1977-05-09", aggregated_at=stale_time),
    ]
    save_aggregation(db, concerts)
    mock_settings = _MockSettings(db)
    monkeypatch.setattr("backend.routes.concerts.settings", mock_settings)
    monkeypatch.setattr("backend.aggregation.orchestrate.settings", mock_settings)
    return db, concerts


@pytest.fixture
def db_empty(tmp_path: Path, monkeypatch) -> Path:
    """Empty DB — artist never aggregated."""
    db = tmp_path / "test.db"
    mock_settings = _MockSettings(db)
    monkeypatch.setattr("backend.routes.concerts.settings", mock_settings)
    monkeypatch.setattr("backend.aggregation.orchestrate.settings", mock_settings)
    return db


# --- List endpoint ---

class TestListConcerts:
    def test_returns_200_and_list_shape(self, db_fresh):
        response = client.get("/concerts?artist=grateful+dead")
        assert response.status_code == 200
        body = response.json()
        assert set(body) == {"concerts", "total", "page", "page_size"}

    def test_pagination_page1(self, db_fresh):
        body = client.get("/concerts?artist=grateful+dead&page=1").json()
        assert body["total"] == 5
        assert body["page"] == 1
        assert body["page_size"] == 3
        assert len(body["concerts"]) == 3

    def test_pagination_page2(self, db_fresh):
        body = client.get("/concerts?artist=grateful+dead&page=2").json()
        assert body["total"] == 5
        assert body["page"] == 2
        assert len(body["concerts"]) == 2  # remaining 2 of 5

    def test_pagination_beyond_last_page(self, db_fresh):
        body = client.get("/concerts?artist=grateful+dead&page=99").json()
        assert body["total"] == 5
        assert len(body["concerts"]) == 0

    def test_concert_list_item_fields(self, db_fresh):
        item = client.get("/concerts?artist=grateful+dead").json()["concerts"][0]
        assert set(item) == {
            "id", "display_artist", "date", "date_precision",
            "display_venue", "location", "recording_count", "preferred_recording_id",
        }

    def test_recording_count_matches_recordings(self, db_fresh):
        items = client.get("/concerts?artist=grateful+dead").json()["concerts"]
        assert all(item["recording_count"] >= 1 for item in items)

    def test_unknown_artist_returns_empty_list_not_404(self, db_empty, monkeypatch):
        monkeypatch.setattr(
            "backend.routes.concerts.aggregate_artist",
            AsyncMock(return_value=[]),
        )
        response = client.get("/concerts?artist=nobody")
        assert response.status_code == 200
        body = response.json()
        assert body["total"] == 0
        assert body["concerts"] == []

    def test_stale_data_triggers_aggregation(self, db_stale, monkeypatch):
        _, stale_concerts = db_stale
        mock_agg = AsyncMock(return_value=stale_concerts)
        monkeypatch.setattr("backend.routes.concerts.aggregate_artist", mock_agg)

        response = client.get("/concerts?artist=grateful+dead")
        assert response.status_code == 200
        mock_agg.assert_called_once()

    def test_route_always_calls_aggregate_artist(self, db_fresh, monkeypatch):
        _, fresh_concerts = db_fresh
        mock_agg = AsyncMock(return_value=fresh_concerts)
        monkeypatch.setattr("backend.routes.concerts.aggregate_artist", mock_agg)

        response = client.get("/concerts?artist=grateful+dead")
        assert response.status_code == 200
        mock_agg.assert_called_once()

    def test_missing_artist_triggers_aggregation(self, db_empty, monkeypatch):
        mock_agg = AsyncMock(return_value=[])
        monkeypatch.setattr("backend.routes.concerts.aggregate_artist", mock_agg)

        client.get("/concerts?artist=new+artist")
        mock_agg.assert_called_once()

    def test_aggregation_timeout_returns_504(self, db_empty, monkeypatch):
        import asyncio

        async def _slow(*args, **kwargs):
            await asyncio.sleep(9999)

        monkeypatch.setattr("backend.routes.concerts._AGGREGATION_TIMEOUT", 0.01)
        monkeypatch.setattr("backend.routes.concerts.aggregate_artist", _slow)

        response = client.get("/concerts?artist=grateful+dead")
        assert response.status_code == 504


# --- Detail endpoint ---

class TestGetConcert:
    def test_not_found_returns_404(self, db_empty):
        response = client.get("/concerts/nonexistent-uuid")
        assert response.status_code == 404

    def test_found_returns_200_and_shape(self, db_fresh):
        _, concerts = db_fresh
        cid = concerts[0].id
        response = client.get(f"/concerts/{cid}")
        assert response.status_code == 200
        body = response.json()
        assert set(body) == {
            "id", "artist", "date", "venue", "location",
            "preferred_recording_id", "recordings",
        }

    def test_correct_id_in_response(self, db_fresh):
        _, concerts = db_fresh
        cid = concerts[2].id
        body = client.get(f"/concerts/{cid}").json()
        assert body["id"] == cid

    def test_recordings_present(self, db_fresh):
        _, concerts = db_fresh
        body = client.get(f"/concerts/{concerts[0].id}").json()
        assert len(body["recordings"]) >= 1

    def test_recording_fields(self, db_fresh):
        _, concerts = db_fresh
        rec = client.get(f"/concerts/{concerts[0].id}").json()["recordings"][0]
        assert set(rec) == {
            "identifier", "source_quality", "source", "taper", "lineage",
            "download_count", "tracks",
        }

    def test_source_quality_in_recording(self, db_fresh):
        _, concerts = db_fresh
        rec = client.get(f"/concerts/{concerts[0].id}").json()["recordings"][0]
        assert rec["source_quality"] in {"SBD", "MTX", "AUD", "FM", "UNKNOWN"}

    def test_recordings_ordered_sbd_before_aud(self, tmp_path, monkeypatch):
        db = tmp_path / "test.db"
        aud_rec = _make_recording("gd77.aud.01", sq=SourceQuality.AUD, downloads=900)
        sbd_rec = _make_recording("gd77.sbd.01", sq=SourceQuality.SBD, downloads=100)
        concert = _make_concert(
            "order-test",
            "1977-05-08",
            recordings=[aud_rec, sbd_rec],  # AUD listed first intentionally
        )
        concert.preferred_recording_id = sbd_rec.identifier
        concert.recordings.sort(
            key=lambda r: (r.source_quality.value, -len(r.tracks), -r.downloads)
        )
        save_aggregation(db, [concert])
        monkeypatch.setattr("backend.routes.concerts.settings", _MockSettings(db))

        body = client.get("/concerts/order-test").json()
        qualities = [r["source_quality"] for r in body["recordings"]]
        assert qualities[0] == "SBD"
        assert qualities[1] == "AUD"

    def test_tracks_have_stream_url(self, db_fresh):
        _, concerts = db_fresh
        tracks = client.get(f"/concerts/{concerts[0].id}").json()["recordings"][0]["tracks"]
        assert len(tracks) > 0
        for track in tracks:
            assert track["stream_url"].startswith("https://archive.org/download/")
            assert track["filename"] in track["stream_url"]

    def test_track_fields(self, db_fresh):
        _, concerts = db_fresh
        track = client.get(f"/concerts/{concerts[0].id}").json()["recordings"][0]["tracks"][0]
        assert set(track) == {"index", "title", "filename", "duration", "stream_url"}

    def test_preferred_recording_id_matches_best_recording(self, db_fresh):
        _, concerts = db_fresh
        body = client.get(f"/concerts/{concerts[0].id}").json()
        identifiers = [r["identifier"] for r in body["recordings"]]
        assert body["preferred_recording_id"] in identifiers
