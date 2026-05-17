import pytest

from backend.tests.helpers import load_fixture
from backend.models.ia import IAItem

_UNSUPPORTED_FORMATS = {"Ogg Vorbis", "Shorten"}
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
    # source and venue are present for this item; taper/lineage may be absent
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
    fixture = load_fixture(_FIXTURE_FILE)
    raw_files = fixture["files"]
    unfiltered = len(raw_files)
    item = _parse_fixture()
    filtered = len(item.files)
    ogg_count = sum(1 for f in raw_files if f.get("format") == "Ogg Vorbis")
    shn_count = sum(1 for f in raw_files if f.get("format") == "Shorten")
    assert filtered == unfiltered - ogg_count - shn_count


def test_file_fields_present():
    item = _parse_fixture()
    audio = [f for f in item.files if f.format in ("Flac", "VBR MP3")]
    assert len(audio) > 0
    first = audio[0]
    assert first.name
    assert first.format
    # length stays as string — no parsing to seconds at this stage
    assert first.length is not None
    assert isinstance(first.length, str)


@pytest.mark.asyncio
@pytest.mark.live_ia
async def test_get_item_metadata_live():
    from backend.core.http_client import IAClient
    from backend.ia.metadata import get_item_metadata

    ia_client = IAClient()
    try:
        item = await get_item_metadata(ia_client, _FIXTURE_IDENTIFIER)
    finally:
        await ia_client.aclose()
    assert item.metadata.identifier == _FIXTURE_IDENTIFIER
    assert len(item.files) > 0
    formats = {f.format for f in item.files}
    assert "Ogg Vorbis" not in formats
