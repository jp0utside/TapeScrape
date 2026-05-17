from fastapi import APIRouter, Depends, HTTPException, Request

from backend.core.cache import MetadataCache
from backend.core.config import settings
from backend.core.http_client import IAClient
from backend.core.logging import get_logger
from backend.ia.metadata import get_item_metadata
from backend.ia.search import search_items
from backend.models.concert import ConcertResponse, RecordingResponse, TrackResponse
from backend.models.ia import IAFile, IAItem

logger = get_logger(__name__)

router = APIRouter(prefix="/concerts")

_cache = MetadataCache(settings.cache_db_path)


def get_ia_client(request: Request) -> IAClient:
    """FastAPI dependency: the single IAClient built in the app lifespan.

    Lives here (not in core/) because core/ may import only stdlib + Pydantic
    (CONVENTIONS §1). Promote to a shared routes/deps.py when a second route
    needs it (Phase 2) — not before.
    """
    return request.app.state.ia_client

# Phase 1: hardcoded map of slug → IA search parameters.
# Phase 2 replaces this with real aggregation + UUID concert IDs.
_CONCERT_MAP: dict[str, dict] = {
    "gd-1977-05-08": {"creator": "Grateful Dead", "date": "1977-05-08"},
}

_TOP_N_RECORDINGS = 3

# Format preference for track deduplication: lower rank = preferred.
_AUDIO_FORMATS = {"Flac", "24bit Flac", "VBR MP3", "MP3", "WAVE"}
_FORMAT_RANK: dict[str, int] = {
    "Flac": 0,
    "24bit Flac": 0,
    "VBR MP3": 1,
    "MP3": 1,
    "WAVE": 2,
}


def _build_tracks(identifier: str, files: list[IAFile]) -> list[TrackResponse]:
    """Group files by stem, pick best format per track, sort by filename."""
    audio = [f for f in files if f.format in _AUDIO_FORMATS]

    # Deduplicate: for each stem keep the highest-quality format.
    best: dict[str, IAFile] = {}
    for f in audio:
        stem = f.name.rsplit(".", 1)[0]
        current_rank = _FORMAT_RANK.get(best[stem].format, 99) if stem in best else 99
        if _FORMAT_RANK.get(f.format, 99) < current_rank:
            best[stem] = f

    sorted_files = sorted(best.values(), key=lambda f: f.name.rsplit(".", 1)[0])

    return [
        TrackResponse(
            index=i,
            title=f.title,
            filename=f.name,
            duration=f.length,
            stream_url=f"https://archive.org/download/{identifier}/{f.name}",
        )
        for i, f in enumerate(sorted_files)
    ]


async def _fetch_item(client: IAClient, identifier: str) -> IAItem:
    """Return IAItem from cache if present; otherwise fetch from IA and cache."""
    cached = await _cache.get(identifier)
    if cached is not None:
        logger.info("cache_hit identifier=%s", identifier)
        return IAItem.model_validate(cached)

    logger.info("cache_miss identifier=%s", identifier)
    item = await get_item_metadata(client, identifier)
    # Store the raw validated data back as a dict for the cache.
    await _cache.set(identifier, item.model_dump())
    return item


def _recording_from_item(item: IAItem, download_count: int) -> RecordingResponse:
    tracks = _build_tracks(item.metadata.identifier, item.files)
    return RecordingResponse(
        identifier=item.metadata.identifier,
        source=item.metadata.source,
        taper=item.metadata.taper,
        lineage=item.metadata.lineage,
        download_count=download_count,
        tracks=tracks,
    )


@router.get("/{concert_id}", response_model=ConcertResponse)
async def get_concert(
    concert_id: str,
    ia_client: IAClient = Depends(get_ia_client),
) -> ConcertResponse:
    params = _CONCERT_MAP.get(concert_id)
    if params is None:
        raise HTTPException(status_code=404, detail=f"Concert '{concert_id}' not found")

    search_result = await search_items(
        ia_client,
        creator=params["creator"],
        date=params["date"],
        rows=50,
    )

    if not search_result.items:
        raise HTTPException(status_code=404, detail="No recordings found for this concert")

    # Take top N by download count.
    top_items = sorted(search_result.items, key=lambda x: x.downloads, reverse=True)[
        :_TOP_N_RECORDINGS
    ]

    recordings: list[RecordingResponse] = []
    top_meta = None
    for i, search_item in enumerate(top_items):
        item = await _fetch_item(ia_client, search_item.identifier)
        if i == 0:
            top_meta = item.metadata
        recordings.append(_recording_from_item(item, search_item.downloads))

    return ConcertResponse(
        id=concert_id,
        artist=top_meta.creator or params["creator"],
        date=params["date"],
        venue=top_meta.venue,
        location=top_meta.coverage,
        preferred_recording_id=recordings[0].identifier,
        recordings=recordings,
    )
