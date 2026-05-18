from pathlib import Path
from unittest.mock import AsyncMock, MagicMock

import pytest

from backend.core.cache import MetadataCache
from backend.core.http_client import IAClient
from backend.ia.metadata import get_item_metadata
from backend.models.ia import IAItem
from backend.tests.helpers import load_fixture

_FIXTURE_IDENTIFIER = "gd1977-05-08.aud.moore.berger.28354.flac16"
_FIXTURE_FILE = f"{_FIXTURE_IDENTIFIER}_metadata.json"


def _parse_fixture() -> IAItem:
    return IAItem.model_validate(load_fixture(_FIXTURE_FILE))


def test_metadata_identifier_and_title():
    item = _parse_fixture()
    assert item.metadata.identifier == _FIXTURE_IDENTIFIER
    assert "Grateful Dead" in item.metadata.title
    assert "1977-05-08" in item.metadata.title


def test_metadata_lineage_fields_preserved():
    item = _parse_fixture()
    assert item.metadata.source is not None
    assert item.metadata.venue is not None
    assert item.metadata.identifier == _FIXTURE_IDENTIFIER


def test_ogg_vorbis_filtered_from_files():
    item = _parse_fixture()
    formats = {f.format for f in item.files}
    assert "Ogg Vorbis" not in formats
    assert "Shorten" not in formats


def test_playable_formats_survive():
    item = _parse_fixture()
    formats = {f.format for f in item.files}
    assert "Flac" in formats
    assert "VBR MP3" in formats


def test_file_count_reduced_by_filter():
    from backend.models.ia import _PLAYABLE_FORMATS
    fixture = load_fixture(_FIXTURE_FILE)
    raw_files = fixture["files"]
    item = _parse_fixture()
    expected = sum(1 for f in raw_files if f.get("format") in _PLAYABLE_FORMATS)
    assert len(item.files) == expected


def test_file_fields_present():
    item = _parse_fixture()
    audio = [f for f in item.files if f.format in ("Flac", "VBR MP3")]
    assert len(audio) > 0
    first = audio[0]
    assert first.name
    assert first.format
    assert first.length is not None
    assert isinstance(first.length, str)


@pytest.mark.asyncio
async def test_get_item_metadata_cache_miss(tmp_path: Path):
    fixture = load_fixture(_FIXTURE_FILE)
    mock_response = MagicMock()
    mock_response.json.return_value = fixture
    mock_client = MagicMock(spec=IAClient)
    mock_client.get = AsyncMock(return_value=mock_response)

    cache = MetadataCache(tmp_path / "meta.db")
    item = await get_item_metadata(mock_client, _FIXTURE_IDENTIFIER, cache)

    assert item.metadata.identifier == _FIXTURE_IDENTIFIER
    mock_client.get.assert_called_once()
    assert await cache.get(_FIXTURE_IDENTIFIER) is not None


@pytest.mark.asyncio
async def test_get_item_metadata_cache_hit(tmp_path: Path):
    fixture = load_fixture(_FIXTURE_FILE)
    cache = MetadataCache(tmp_path / "meta.db")
    await cache.set(_FIXTURE_IDENTIFIER, fixture)

    mock_client = MagicMock(spec=IAClient)
    mock_client.get = AsyncMock()

    item = await get_item_metadata(mock_client, _FIXTURE_IDENTIFIER, cache)

    assert item.metadata.identifier == _FIXTURE_IDENTIFIER
    mock_client.get.assert_not_called()


@pytest.mark.asyncio
@pytest.mark.live_ia
async def test_get_item_metadata_live(tmp_path: Path):
    ia_client = IAClient()
    cache = MetadataCache(tmp_path / "meta.db")
    try:
        item = await get_item_metadata(ia_client, _FIXTURE_IDENTIFIER, cache)
    finally:
        await ia_client.aclose()
    assert item.metadata.identifier == _FIXTURE_IDENTIFIER
    assert len(item.files) > 0
    formats = {f.format for f in item.files}
    assert "Ogg Vorbis" not in formats
