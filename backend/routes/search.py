import hashlib
import sqlite3

from fastapi import APIRouter, Depends, HTTPException

from backend.aggregation.canonicalize import canonical_artist_key, display_artist
from backend.aggregation.source_quality import SourceQuality
from backend.core.cache import SearchCache
from backend.core.config import settings
from backend.core.http_client import IAClient
from backend.core.logging import get_logger
from backend.db.repository import _ensure_tables
from backend.ia.search import search_items
from backend.models.ia import IASearchResult
from backend.models.search import ArtistMatch, ArtistSearchResponse, TrackMatch, TrackSearchResponse
from backend.routes.deps import get_db_path, get_ia_client, get_search_cache

logger = get_logger(__name__)

router = APIRouter()

_SUPPORTED_TYPES = {"artist", "concert", "track"}
_NOT_YET = {
    "concert": "concert search is not implemented",
}


def _cache_key(type_: str, q: str, page: int) -> str:
    normalized = f"{type_}|{q.strip().lower()}|{page}"
    return hashlib.sha256(normalized.encode()).hexdigest()


async def _search_tracks(q: str, db_path: str, limit: int = 50) -> TrackSearchResponse:
    _ensure_tables(db_path)
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            """SELECT t.title, t.filename, t.duration, t.stream_url,
                      r.identifier AS recording_identifier, r.source_quality,
                      c.id AS concert_id, c.display_artist, c.date, c.display_venue
               FROM tracks t
               JOIN recordings r ON t.recording_id = r.identifier
               JOIN concerts c ON r.concert_id = c.id
               WHERE t.title LIKE ? COLLATE NOCASE
               ORDER BY c.date DESC
               LIMIT ?""",
            (f"%{q}%", limit),
        ).fetchall()

    results = [
        TrackMatch(
            title=row["title"],
            filename=row["filename"],
            duration=row["duration"],
            stream_url=row["stream_url"],
            recording_identifier=row["recording_identifier"],
            concert_id=row["concert_id"],
            artist=row["display_artist"],
            date=row["date"],
            venue=row["display_venue"],
            source_quality=SourceQuality(row["source_quality"]).name,
        )
        for row in rows
    ]
    return TrackSearchResponse(query=q, results=results, total=len(results))


@router.get("/search")
async def search(
    q: str,
    type: str = "artist",
    page: int = 1,
    ia_client: IAClient = Depends(get_ia_client),
    search_cache: SearchCache = Depends(get_search_cache),
    db_path: str = Depends(get_db_path),
) -> ArtistSearchResponse | TrackSearchResponse:
    if type not in _SUPPORTED_TYPES:
        raise HTTPException(
            status_code=422,
            detail=f"Unsupported search type '{type}'. Expected: artist, concert, track",
        )
    if type in _NOT_YET:
        raise HTTPException(status_code=501, detail=_NOT_YET[type])

    if type == "track":
        logger.info("track_search q=%s", q)
        return await _search_tracks(q, db_path)

    key = _cache_key(type, q, page)
    cached = await search_cache.get(key)
    if cached is not None:
        logger.info("search_cache_hit type=%s q=%s page=%s", type, q, page)
        result = IASearchResult.model_validate(cached)
    else:
        logger.info("search_cache_miss type=%s q=%s page=%s", type, q, page)
        result = await search_items(ia_client, creator=q, page=page)
        await search_cache.set(
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
