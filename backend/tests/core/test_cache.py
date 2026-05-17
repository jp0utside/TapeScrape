import time
from pathlib import Path

import pytest

from backend.core.cache import MetadataCache


@pytest.fixture
def cache(tmp_path: Path) -> MetadataCache:
    return MetadataCache(tmp_path / "test_cache.db")


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
