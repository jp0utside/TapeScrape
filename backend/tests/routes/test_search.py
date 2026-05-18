import sqlite3
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from backend.aggregation.source_quality import SourceQuality
from backend.core.cache import SearchCache
from backend.db.repository import _ensure_tables
from backend.main import app
from backend.models.ia import IASearchItem, IASearchResult
from backend.routes.deps import get_db_path, get_ia_client, get_search_cache
from backend.tests.helpers import load_fixture

client = TestClient(app)


def _fixture_search_result() -> IASearchResult:
    fixture = load_fixture("gd1977-05-08_search.json")
    docs = fixture["response"]["docs"]
    items = [IASearchItem.model_validate(d) for d in docs]
    return IASearchResult(items=items, total=fixture["response"]["numFound"])


def _seed_track_db(db_path: str) -> None:
    """Insert one concert/recording/track for track-search tests."""
    _ensure_tables(db_path)
    with sqlite3.connect(db_path) as conn:
        conn.execute(
            "INSERT INTO concerts (id, canonical_artist, display_artist, date, "
            "date_precision, canonical_venue, display_venue, location, "
            "preferred_recording_id, aggregated_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
            ("c1", "grateful dead", "Grateful Dead", "1977-05-08", "day",
             "cornell", "Cornell University", "Ithaca, NY", "r1", 0.0),
        )
        conn.execute(
            "INSERT INTO recordings (identifier, concert_id, source_quality, "
            "source, taper, lineage, downloads, sort_order) VALUES (?,?,?,?,?,?,?,?)",
            ("r1", "c1", SourceQuality.SBD.value, "SBD", "unknown", None, 0, 0),
        )
        conn.execute(
            "INSERT INTO tracks (recording_id, idx, title, filename, duration, "
            "size, stream_url) VALUES (?,?,?,?,?,?,?)",
            ("r1", 1, "Scarlet Begonias", "d1t01.flac", "5:12", None,
             "https://archive.org/stream/r1/d1t01.flac"),
        )
        conn.execute(
            "INSERT INTO tracks (recording_id, idx, title, filename, duration, "
            "size, stream_url) VALUES (?,?,?,?,?,?,?)",
            ("r1", 2, "Fire on the Mountain", "d1t02.flac", "7:33", None,
             "https://archive.org/stream/r1/d1t02.flac"),
        )
        conn.commit()


@pytest.fixture(autouse=True)
def _isolate(tmp_path):
    """Inject a dummy IAClient, a fresh SearchCache, and a per-test DB path."""
    db_path = str(tmp_path / "test.db")
    search_cache = SearchCache(tmp_path / "s.db")
    app.dependency_overrides[get_ia_client] = lambda: object()
    app.dependency_overrides[get_search_cache] = lambda: search_cache
    app.dependency_overrides[get_db_path] = lambda: db_path
    yield db_path
    app.dependency_overrides.pop(get_ia_client, None)
    app.dependency_overrides.pop(get_search_cache, None)
    app.dependency_overrides.pop(get_db_path, None)


def test_artist_search_collapses_to_canonical():
    mock = AsyncMock(return_value=_fixture_search_result())
    with patch("backend.routes.search.search_items", mock):
        body = client.get("/search", params={"type": "artist", "q": "grateful dead"}).json()

    assert body["query"] == "grateful dead"
    assert body["type"] == "artist"
    assert len(body["matches"]) == 1
    match = body["matches"][0]
    assert match["canonical_artist"] == "grateful dead"
    assert match["display_artist"] == "Grateful Dead"
    # All 8 fixture items are one taper-distinct recording each.
    assert match["recording_count"] == 8


def test_artist_defaults_when_type_omitted():
    mock = AsyncMock(return_value=_fixture_search_result())
    with patch("backend.routes.search.search_items", mock):
        resp = client.get("/search", params={"q": "grateful dead"})
    assert resp.status_code == 200
    assert resp.json()["type"] == "artist"


def test_second_call_is_served_from_cache():
    mock = AsyncMock(return_value=_fixture_search_result())
    with patch("backend.routes.search.search_items", mock):
        client.get("/search", params={"type": "artist", "q": "grateful dead"})
        client.get("/search", params={"type": "artist", "q": "grateful dead"})
    assert mock.await_count == 1  # second request hit the search cache


def test_variant_creators_collapse_into_one_match():
    mixed = IASearchResult(
        items=[
            IASearchItem(identifier="a", title="A", creator="Grateful Dead"),
            IASearchItem(identifier="b", title="B", creator="The Grateful Dead"),
            IASearchItem(identifier="c", title="C", creator="Grateful Dead, The"),
            IASearchItem(identifier="d", title="D", creator="Phish"),
        ],
        total=4,
    )
    with patch("backend.routes.search.search_items", AsyncMock(return_value=mixed)):
        body = client.get("/search", params={"type": "artist", "q": "x"}).json()

    by_key = {m["canonical_artist"]: m for m in body["matches"]}
    assert set(by_key) == {"grateful dead", "phish"}
    assert by_key["grateful dead"]["recording_count"] == 3
    assert by_key["grateful dead"]["display_artist"] == "Grateful Dead"
    # Sorted by recording_count desc.
    assert body["matches"][0]["canonical_artist"] == "grateful dead"


def test_items_without_creator_are_skipped():
    no_creator = IASearchResult(
        items=[
            IASearchItem(identifier="a", title="A", creator="Phish"),
            IASearchItem(identifier="b", title="B"),  # creator None
        ],
        total=2,
    )
    with patch("backend.routes.search.search_items", AsyncMock(return_value=no_creator)):
        body = client.get("/search", params={"type": "artist", "q": "x"}).json()
    assert len(body["matches"]) == 1
    assert body["matches"][0]["recording_count"] == 1


def test_concert_type_is_honest_501():
    resp = client.get("/search", params={"type": "concert", "q": "x"})
    assert resp.status_code == 501
    assert "concert search is not implemented" in resp.json()["detail"]


def test_unknown_type_is_rejected():
    resp = client.get("/search", params={"type": "bogus", "q": "x"})
    assert resp.status_code == 422


def test_missing_query_is_rejected():
    resp = client.get("/search", params={"type": "artist"})
    assert resp.status_code == 422


# --- Track search tests ---

def test_track_search_returns_matching_tracks(_isolate):
    _seed_track_db(_isolate)
    resp = client.get("/search", params={"type": "track", "q": "Scarlet"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["type"] == "track"
    assert body["query"] == "Scarlet"
    assert body["total"] == 1
    assert len(body["results"]) == 1
    assert body["results"][0]["title"] == "Scarlet Begonias"


def test_track_search_no_matches_returns_empty(_isolate):
    _seed_track_db(_isolate)
    resp = client.get("/search", params={"type": "track", "q": "Dark Star"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 0
    assert body["results"] == []


def test_track_search_includes_concert_context(_isolate):
    _seed_track_db(_isolate)
    resp = client.get("/search", params={"type": "track", "q": "Fire"})
    assert resp.status_code == 200
    r = resp.json()["results"][0]
    assert r["artist"] == "Grateful Dead"
    assert r["date"] == "1977-05-08"
    assert r["venue"] == "Cornell University"
    assert r["concert_id"] == "c1"
    assert r["recording_identifier"] == "r1"
    assert r["source_quality"] == "SBD"


def test_track_search_is_case_insensitive(_isolate):
    _seed_track_db(_isolate)
    resp_lower = client.get("/search", params={"type": "track", "q": "scarlet"})
    resp_upper = client.get("/search", params={"type": "track", "q": "SCARLET"})
    assert resp_lower.json()["total"] == 1
    assert resp_upper.json()["total"] == 1


def test_track_search_empty_db_returns_empty(_isolate):
    # No seeding — tables are created lazily but have no rows.
    resp = client.get("/search", params={"type": "track", "q": "anything"})
    assert resp.status_code == 200
    assert resp.json()["total"] == 0
