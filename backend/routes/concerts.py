import asyncio

from fastapi import APIRouter, Depends, HTTPException, Query

from backend.aggregation.aggregate import AggregatedConcert
from backend.aggregation.orchestrate import aggregate_artist
from backend.core.cache import MetadataCache
from backend.core.config import settings
from backend.core.http_client import IAClient
from backend.core.logging import get_logger
from backend.db.repository import get_concert_by_id
from backend.models.concert import (
    ConcertDetailResponse,
    ConcertListItem,
    ConcertListResponse,
    RecordingResponse,
    TrackResponse,
)
from backend.routes.deps import get_ia_client, get_metadata_cache

logger = get_logger(__name__)

router = APIRouter(prefix="/concerts")

_AGGREGATION_TIMEOUT = 30.0


def _to_list_item(concert: AggregatedConcert) -> ConcertListItem:
    return ConcertListItem(
        id=concert.id,
        display_artist=concert.display_artist,
        date=concert.date,
        date_precision=concert.date_precision,
        display_venue=concert.display_venue,
        location=concert.location,
        recording_count=len(concert.recordings),
        preferred_recording_id=concert.preferred_recording_id,
    )


def _to_detail_response(concert: AggregatedConcert) -> ConcertDetailResponse:
    recordings = [
        RecordingResponse(
            identifier=rec.identifier,
            source_quality=rec.source_quality.name,
            source=rec.source,
            taper=rec.taper,
            lineage=rec.lineage,
            download_count=rec.downloads,
            tracks=[
                TrackResponse(
                    index=t.index,
                    title=t.title,
                    filename=t.filename,
                    duration=t.duration,
                    stream_url=t.stream_url,
                )
                for t in rec.tracks
            ],
        )
        for rec in concert.recordings
    ]
    return ConcertDetailResponse(
        id=concert.id,
        artist=concert.display_artist,
        date=concert.date,
        venue=concert.display_venue,
        location=concert.location,
        preferred_recording_id=concert.preferred_recording_id,
        recordings=recordings,
    )


@router.get("", response_model=ConcertListResponse)
async def list_concerts(
    artist: str,
    page: int = Query(1, ge=1),
    ia_client: IAClient = Depends(get_ia_client),
    metadata_cache: MetadataCache = Depends(get_metadata_cache),
) -> ConcertListResponse:
    try:
        concerts = await asyncio.wait_for(
            aggregate_artist(artist, ia_client, metadata_cache, force=False),
            timeout=_AGGREGATION_TIMEOUT,
        )
    except asyncio.TimeoutError:
        logger.error("aggregation_timeout artist=%s", artist)
        raise HTTPException(status_code=504, detail="Aggregation timed out")

    total = len(concerts)
    page_size = settings.concerts_page_size
    offset = (page - 1) * page_size
    page_concerts = concerts[offset : offset + page_size]

    return ConcertListResponse(
        concerts=[_to_list_item(c) for c in page_concerts],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/{concert_id}", response_model=ConcertDetailResponse)
async def get_concert(concert_id: str) -> ConcertDetailResponse:
    db_path = settings.cache_db_path
    concert = get_concert_by_id(db_path, concert_id)
    if concert is None:
        raise HTTPException(status_code=404, detail=f"Concert '{concert_id}' not found")
    return _to_detail_response(concert)
