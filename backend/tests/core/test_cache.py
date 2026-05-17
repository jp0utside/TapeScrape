import time
from pathlib import Path

import pytest

from backend.core.cache import MetadataCache, SearchCache


@pytest.fixture
def cache(tmp_path: Path) -> MetadataCache:
    return MetadataCache(tmp_path / "test_cache.db")


@pytest.fixture
def search_cache(tmp_path: Path) -> SearchCache:
    return SearchCache(tmp_path / "test_cache.db")


async def test_get_returns_none_on_miss(cache: MetadataCache):
    result = await cache.get("nonexistent-id")
    assert result is None


async def test_set_then_get_returns_data(cache: MetadataCache):
    data = {"identifier": "test-id", "files": []}
    await cache.set("test-id", data)
    result = await cache.get("test-id")
    assert result == data


async def test_get_returns_none_after_ttl_expires(cache: MetadataCache):
    data = {"identifier": "test-id"}
    await cache.set("test-id", data, ttl_seconds=0)
    # TTL of 0 means expires_at = now; any subsequent read is past expiry.
    time.sleep(0.01)
    result = await cache.get("test-id")
    assert result is None


async def test_set_overwrites_existing_entry(cache: MetadataCache):
    await cache.set("test-id", {"v": 1})
    await cache.set("test-id", {"v": 2})
    result = await cache.get("test-id")
    assert result == {"v": 2}


async def test_multiple_identifiers_are_independent(cache: MetadataCache):
    await cache.set("id-a", {"key": "a"})
    await cache.set("id-b", {"key": "b"})
    assert (await cache.get("id-a")) == {"key": "a"}
    assert (await cache.get("id-b")) == {"key": "b"}
    assert (await cache.get("id-c")) is None


async def test_search_cache_set_then_get(search_cache: SearchCache):
    data = {"items": [], "total": 0}
    await search_cache.set("k1", data)
    assert (await search_cache.get("k1")) == data


async def test_search_cache_miss_returns_none(search_cache: SearchCache):
    assert (await search_cache.get("absent")) is None


async def test_search_cache_expires(search_cache: SearchCache):
    await search_cache.set("k1", {"v": 1}, ttl_seconds=0)
    time.sleep(0.01)
    assert (await search_cache.get("k1")) is None


async def test_search_cache_is_separate_table_from_metadata(
    cache: MetadataCache, search_cache: SearchCache
):
    # Same DB file (both fixtures use tmp_path/"test_cache.db"); distinct
    # tables → a key set in one is not visible in the other.
    await cache.set("shared-key", {"from": "metadata"})
    await search_cache.set("shared-key", {"from": "search"})
    assert (await cache.get("shared-key")) == {"from": "metadata"}
    assert (await search_cache.get("shared-key")) == {"from": "search"}
