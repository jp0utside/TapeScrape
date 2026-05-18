"""Top-level aggregation orchestrator — fetch, aggregate, persist.

The single entry point for "aggregate an artist": searches IA, fetches
metadata for a sample of items per candidate concert, runs the pure
aggregation logic, and persists the result. Respects on-demand-when-stale:
skips if a fresh aggregation exists (unless force=True).
"""

from collections import defaultdict

from backend.aggregation.aggregate import AggregatedConcert, aggregate_items
from backend.aggregation.canonicalize import display_artist
from backend.core.cache import MetadataCache
from backend.core.config import settings
from backend.core.http_client import IAClient
from backend.core.logging import get_logger
from backend.db.repository import (
    get_aggregation_age,
    get_concerts_for_artist,
    save_aggregation,
)
from backend.ia.metadata import get_item_metadata
from backend.ia.search import search_items

logger = get_logger(__name__)

_SAMPLE_SIZE = 3


async def aggregate_artist(
    canonical_artist: str,
    ia_client: IAClient,
    metadata_cache: MetadataCache,
    force: bool = False,
) -> list[AggregatedConcert]:
    """Fetch, aggregate, persist. Skip if fresh (unless force=True)."""
    db_path = settings.cache_db_path

    if not force:
        age = get_aggregation_age(db_path, canonical_artist)
        if age is not None and age < settings.aggregation_staleness_seconds:
            return get_concerts_for_artist(db_path, canonical_artist)

    # Search IA for all items by this artist (page 1 for now)
    result = await search_items(ia_client, creator=canonical_artist, rows=50, page=1)

    if not result.items:
        return []

    # Determine display artist from raw creator names
    raw_creators = [item.creator for item in result.items if item.creator]
    disp_artist = display_artist(raw_creators) if raw_creators else canonical_artist

    # Group items by date to decide which to sample metadata for
    by_date: defaultdict[str, list] = defaultdict(list)
    for item in result.items:
        date_key = (item.date or "")[:10]
        by_date[date_key].append(item)

    # Fetch metadata for top-N items per date group (by downloads)
    identifiers_to_fetch: list[str] = []
    for date_key, items in by_date.items():
        sorted_items = sorted(items, key=lambda i: i.downloads, reverse=True)
        for item in sorted_items[:_SAMPLE_SIZE]:
            identifiers_to_fetch.append(item.identifier)

    fetched = {}
    for identifier in identifiers_to_fetch:
        try:
            ia_item = await get_item_metadata(ia_client, identifier, metadata_cache)
            fetched[identifier] = ia_item
        except Exception:
            logger.warning("metadata_fetch_failed identifier=%s", identifier, exc_info=True)
            continue

    concerts = aggregate_items(canonical_artist, disp_artist, result.items, fetched)

    if concerts:
        save_aggregation(db_path, concerts)

    return concerts
