import hashlib

from fastapi import APIRouter, Depends, HTTPException

from backend.aggregation.canonicalize import canonical_artist_key, display_artist
from backend.core.cache import SearchCache
from backend.core.config import settings
from backend.core.http_client import IAClient
from backend.core.logging import get_logger
from backend.ia.search import search_items
from backend.models.ia import IASearchResult
from backend.models.search import ArtistMatch, ArtistSearchResponse
from backend.routes.deps import get_ia_client

logger = get_logger(__name__)

router = APIRouter()

# Module-global cache, consistent with the Phase-1 MetadataCache pattern in
# routes/concerts.py. Unifying caches onto app.state is a separately-tracked
# post-Phase-1 follow-up — deliberately not done here.
_cache = SearchCache(settings.cache_db_path)

_SUPPORTED_TYPES = {"artist", "concert", "track"}
_NOT_YET = {
    "concert": "concert aggregation lands in packets 02-002/02-003",
    "track": (
        "track search is scoped/future per 00-ARCHITECTURE.md §4; the "
        "track_index table lands when track search does, not before"
    ),
}


def _cache_key(type_: str, q: str, page: int) -> str:
    normalized = f"{type_}|{q.strip().lower()}|{page}"
    return hashlib.sha256(normalized.encode()).hexdigest()


@router.get("/search", response_model=ArtistSearchResponse)
async def search(
    q: str,
    type: str = "artist",
    page: int = 1,
    ia_client: IAClient = Depends(get_ia_client),
) -> ArtistSearchResponse:
    if type not in _SUPPORTED_TYPES:
        raise HTTPException(
            status_code=422,
            detail=f"Unsupported search type '{type}'. Expected: artist, concert, track",
        )
    if type in _NOT_YET:
        # Honest 501 — the param shape accepts the type (F1 not foreclosed)
        # but the feature genuinely does not exist yet.
        raise HTTPException(status_code=501, detail=_NOT_YET[type])

    key = _cache_key(type, q, page)
    cached = await _cache.get(key)
    if cached is not None:
        logger.info("search_cache_hit type=%s q=%s page=%s", type, q, page)
        result = IASearchResult.model_validate(cached)
    else:
        logger.info("search_cache_miss type=%s q=%s page=%s", type, q, page)
        result = await search_items(ia_client, creator=q, page=page)
        await _cache.set(
            key, result.model_dump(), ttl_seconds=settings.search_cache_ttl_seconds
        )

    grouped: dict[str, list[str]] = {}
    for item in result.items:
        if not item.creator:
            continue
        ck = canonical_artist_key(item.creator)
        if not ck:
            continue
        grouped.setdefault(ck, []).append(item.creator)

    matches = [
        ArtistMatch(
            canonical_artist=ck,
            display_artist=display_artist(names),
            recording_count=len(names),
        )
        for ck, names in grouped.items()
    ]
    matches.sort(key=lambda m: m.recording_count, reverse=True)

    return ArtistSearchResponse(query=q, type=type, matches=matches)
