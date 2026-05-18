"""Tests for aggregation/orchestrate.py."""

import logging
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from backend.aggregation.orchestrate import aggregate_artist
from backend.core.cache import MetadataCache
from backend.models.ia import IAItem, IAItemMetadata, IASearchItem, IASearchResult


def _make_search_result(items: list[IASearchItem]) -> IASearchResult:
    return IASearchResult(items=items, total=len(items))


def _make_ia_item(identifier: str, date: str = "1977-05-08") -> IAItem:
    return IAItem(
        metadata=IAItemMetadata(
            identifier=identifier,
            title="Concert",
            creator="Test Artist",
            date=date,
        ),
        files=[
            {"name": "track01.flac", "format": "Flac", "title": "Song", "length": "5:00", "size": "1"},
        ],
    )


@pytest.mark.asyncio
async def test_failed_metadata_fetch_logs_warning_and_continues(tmp_path: Path, caplog):
    search_result = _make_search_result([
        IASearchItem(identifier="fail-item", title="A", creator="Test Artist", date="1977-05-08", downloads=100),
        IASearchItem(identifier="ok-item", title="B", creator="Test Artist", date="1977-05-09", downloads=100),
    ])

    ok_item = _make_ia_item("ok-item", date="1977-05-09")

    async def mock_get_metadata(client, identifier, cache):
        if identifier == "fail-item":
            raise RuntimeError("simulated IA failure")
        return ok_item

    metadata_cache = MetadataCache(tmp_path / "meta.db")
    mock_client = MagicMock()
    mock_settings = MagicMock()
    mock_settings.cache_db_path = tmp_path / "concerts.db"
    mock_settings.aggregation_staleness_seconds = 86400

    with patch("backend.aggregation.orchestrate.search_items", AsyncMock(return_value=search_result)), \
         patch("backend.aggregation.orchestrate.get_item_metadata", side_effect=mock_get_metadata), \
         patch("backend.aggregation.orchestrate.settings", mock_settings), \
         patch("backend.aggregation.orchestrate.save_aggregation"), \
         caplog.at_level(logging.WARNING):

        concerts = await aggregate_artist("test artist", mock_client, metadata_cache, force=True)

    warning_messages = [r.message for r in caplog.records if r.levelno == logging.WARNING]
    assert any("fail-item" in msg for msg in warning_messages)

    all_identifiers = {
        rec.identifier
        for concert in concerts
        for rec in concert.recordings
    }
    assert "ok-item" in all_identifiers


@pytest.mark.asyncio
async def test_aggregation_run_completes_when_all_fetches_fail(tmp_path: Path, caplog):
    search_result = _make_search_result([
        IASearchItem(identifier="fail-1", title="A", creator="Test Artist", date="1977-05-08", downloads=100),
    ])

    metadata_cache = MetadataCache(tmp_path / "meta.db")
    mock_client = MagicMock()
    mock_settings = MagicMock()
    mock_settings.cache_db_path = tmp_path / "concerts.db"
    mock_settings.aggregation_staleness_seconds = 86400

    with patch("backend.aggregation.orchestrate.search_items", AsyncMock(return_value=search_result)), \
         patch("backend.aggregation.orchestrate.get_item_metadata", side_effect=RuntimeError("IA down")), \
         patch("backend.aggregation.orchestrate.settings", mock_settings), \
         caplog.at_level(logging.WARNING):

        concerts = await aggregate_artist("test artist", mock_client, metadata_cache, force=True)

    assert any("fail-1" in r.message for r in caplog.records if r.levelno == logging.WARNING)
    assert isinstance(concerts, list)
