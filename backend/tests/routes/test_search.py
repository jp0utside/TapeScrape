from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from backend.core.cache import SearchCache
from backend.main import app
from backend.models.ia import IASearchItem, IASearchResult
from backend.routes.deps import get_ia_client
from backend.tests.helpers import load_fixture

client = TestClient(app)


def _fixture_search_result() -> IASearchResult:
    fixture = load_fixture("gd1977-05-08_search.json")
    docs = fixture["response"]["docs"]
    items = [IASearchItem.model_validate(d) for d in docs]
    return IASearchResult(items=items, total=fixture["response"]["numFound"])


@pytest.fixture(autouse=True)
def _isolate(tmp_path):
    """Module-scope TestClient never runs the lifespan, so inject a dummy
    IAClient (search_items is mocked in every test that reaches it). Give
    each test a fresh on-disk SearchCache so cache-hit assertions are
    deterministic.
    """
    app.dependency_overrides[get_ia_client] = lambda: object()
    with patch("backend.routes.search._cache", SearchCache(tmp_path / "s.db")):
        yield
    app.dependency_overrides.pop(get_ia_client, None)


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
    assert "02-002" in resp.json()["detail"]


def test_track_type_is_honest_501():
    resp = client.get("/search", params={"type": "track", "q": "x"})
    assert resp.status_code == 501


def test_unknown_type_is_rejected():
    resp = client.get("/search", params={"type": "bogus", "q": "x"})
    assert resp.status_code == 422


def test_missing_query_is_rejected():
    resp = client.get("/search", params={"type": "artist"})
    assert resp.status_code == 422
