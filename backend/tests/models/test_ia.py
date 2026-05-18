"""Unit tests for models/ia.py — format allowlist behavior."""

from backend.models.ia import IAItem, IAItemMetadata, _PLAYABLE_FORMATS


def _make_item(files: list[dict]) -> IAItem:
    return IAItem(
        metadata=IAItemMetadata(identifier="test-id", title="Test Concert"),
        files=files,
    )


def test_bitrate_mp3_variants_survive_parse():
    files = [
        {"name": "t1.mp3", "format": "64Kbps MP3", "title": "Song A", "length": "5:00", "size": "1"},
        {"name": "t2.mp3", "format": "128Kbps MP3", "title": "Song B", "length": "5:00", "size": "1"},
        {"name": "t3.ogg", "format": "Ogg Vorbis", "title": "Song A", "length": "5:00", "size": "1"},
    ]
    item = _make_item(files)
    formats = {f.format for f in item.files}
    assert "64Kbps MP3" in formats
    assert "128Kbps MP3" in formats
    assert "Ogg Vorbis" not in formats


def test_vbr_mp3_survives_parse():
    files = [{"name": "t1.mp3", "format": "VBR MP3", "title": "Song", "length": "5:00", "size": "1"}]
    item = _make_item(files)
    assert item.files[0].format == "VBR MP3"


def test_flac_variants_survive_parse():
    files = [
        {"name": "t1.flac", "format": "Flac", "title": "A", "length": "5:00", "size": "1"},
        {"name": "t2.flac", "format": "FLAC", "title": "B", "length": "5:00", "size": "1"},
        {"name": "t3.flac", "format": "24bit Flac", "title": "C", "length": "5:00", "size": "1"},
    ]
    item = _make_item(files)
    assert len(item.files) == 3


def test_non_audio_formats_dropped():
    files = [
        {"name": "cover.jpg", "format": "JPEG", "title": None, "length": None, "size": "50000"},
        {"name": "notes.txt", "format": "Text", "title": None, "length": None, "size": "1000"},
        {"name": "t1.flac", "format": "Flac", "title": "Song", "length": "5:00", "size": "1"},
    ]
    item = _make_item(files)
    assert len(item.files) == 1
    assert item.files[0].format == "Flac"


def test_shorten_dropped():
    files = [
        {"name": "t1.shn", "format": "Shorten", "title": "Song", "length": "5:00", "size": "1"},
        {"name": "t1.flac", "format": "Flac", "title": "Song", "length": "5:00", "size": "1"},
    ]
    item = _make_item(files)
    formats = {f.format for f in item.files}
    assert "Shorten" not in formats
    assert "Flac" in formats


def test_empty_files_produces_empty_list():
    item = _make_item([])
    assert item.files == []


def test_playable_formats_set_contains_expected_entries():
    assert "VBR MP3" in _PLAYABLE_FORMATS
    assert "64Kbps MP3" in _PLAYABLE_FORMATS
    assert "128Kbps MP3" in _PLAYABLE_FORMATS
    assert "Flac" in _PLAYABLE_FORMATS
    assert "Ogg Vorbis" not in _PLAYABLE_FORMATS
    assert "Shorten" not in _PLAYABLE_FORMATS
