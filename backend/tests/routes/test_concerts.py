from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from backend.main import app
from backend.models.ia import IAItem, IASearchItem, IASearchResult
from backend.tests.helpers import load_fixture

client = TestClient(app)

_CONCERT_ID = "gd-1977-05-08"
_METADATA_FIXTURE = "gd1977-05-08.aud.moore.berger.28354.flac16_metadata.json"


def _make_search_result() -> IASearchResult:
    fixture = load_fixture("gd1977-05-08_search.json")
    docs = fixture["response"]["docs"]
    items = [IASearchItem.model_validate(d) for d in docs]
    return IASearchResult(items=items, total=fixture["response"]["numFound"])


def _make_ia_item() -> IAItem:
    return IAItem.model_validate(load_fixture(_METADATA_FIXTURE))


def _patched_concert(search_result: IASearchResult, ia_item: IAItem):
    """Context manager that stubs IA calls for the concert endpoint."""
    return patch.multiple(
        "backend.routes.concerts",
        search_items=AsyncMock(return_value=search_result),
        _fetch_item=AsyncMock(return_value=ia_item),
    )


def test_unknown_concert_returns_404():
    response = client.get("/concerts/unknown-id")
    assert response.status_code == 404


def test_concert_response_status_and_id():
    with _patched_concert(_make_search_result(), _make_ia_item()):
        response = client.get(f"/concerts/{_CONCERT_ID}")
    assert response.status_code == 200
    body = response.json()
    assert body["id"] == _CONCERT_ID


def test_concert_top_level_fields():
    with _patched_concert(_make_search_result(), _make_ia_item()):
        body = client.get(f"/concerts/{_CONCERT_ID}").json()
    assert body["artist"] == "Grateful Dead"
    assert body["date"] == "1977-05-08"
    assert "preferred_recording_id" in body
    assert body["preferred_recording_id"]  # non-empty


def test_concert_has_recordings():
    with _patched_concert(_make_search_result(), _make_ia_item()):
        body = client.get(f"/concerts/{_CONCERT_ID}").json()
    recordings = body["recordings"]
    assert len(recordings) > 0
    # Capped at _TOP_N_RECORDINGS (3) even though search returns 8 items.
    assert len(recordings) <= 3


def test_recording_lineage_fields_present():
    with _patched_concert(_make_search_result(), _make_ia_item()):
        body = client.get(f"/concerts/{_CONCERT_ID}").json()
    rec = body["recordings"][0]
    assert "identifier" in rec
    assert "source" in rec
    assert "taper" in rec
    assert "lineage" in rec
    assert "download_count" in rec


def test_tracks_present_and_ordered():
    with _patched_concert(_make_search_result(), _make_ia_item()):
        body = client.get(f"/concerts/{_CONCERT_ID}").json()
    tracks = body["recordings"][0]["tracks"]
    assert len(tracks) > 0
    indices = [t["index"] for t in tracks]
    assert indices == list(range(len(tracks)))


def test_track_stream_url_is_opaque_archive_url():
    with _patched_concert(_make_search_result(), _make_ia_item()):
        body = client.get(f"/concerts/{_CONCERT_ID}").json()
    for track in body["recordings"][0]["tracks"]:
        assert track["stream_url"].startswith("https://archive.org/download/")
        assert track["filename"] in track["stream_url"]


def test_no_ogg_or_shorten_in_tracks():
    with _patched_concert(_make_search_result(), _make_ia_item()):
        body = client.get(f"/concerts/{_CONCERT_ID}").json()
    for rec in body["recordings"]:
        for track in rec["tracks"]:
            assert not track["filename"].endswith(".ogg")
            assert not track["filename"].endswith(".shn")


def test_preferred_recording_id_matches_first_recording():
    with _patched_concert(_make_search_result(), _make_ia_item()):
        body = client.get(f"/concerts/{_CONCERT_ID}").json()
    assert body["preferred_recording_id"] == body["recordings"][0]["identifier"]


@pytest.mark.live_ia
async def test_concert_endpoint_live():
    """Hits real IA — skipped by default; run with pytest -m live_ia."""
    response = client.get(f"/concerts/{_CONCERT_ID}")
    assert response.status_code == 200
    body = response.json()
    assert body["id"] == _CONCERT_ID
    assert len(body["recordings"]) > 0
    assert len(body["recordings"][0]["tracks"]) > 0
