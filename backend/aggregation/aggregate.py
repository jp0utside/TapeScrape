"""Core concert aggregation — group IA items into canonical concerts.

Pure logic: given typed inputs (search items + fetched metadata), produce
typed outputs (AggregatedConcert list). No I/O here; orchestrate.py handles
fetching and persisting.
"""

import re
import time
import uuid
from dataclasses import dataclass, field

from backend.aggregation.canonicalize import canonical_artist_key, display_artist
from backend.aggregation.source_quality import SourceQuality, parse_source_quality
from backend.aggregation.venue import canonical_venue_key, cluster_venues, display_venue
from backend.models.ia import IAItem, IASearchItem

_NAMESPACE = uuid.UUID("a1b2c3d4-e5f6-7890-abcd-ef1234567890")

_DATE_FULL = re.compile(r"^\d{4}-\d{2}-\d{2}$")
_DATE_YEAR = re.compile(r"^\d{4}$")

_PLAYABLE_FORMATS = {"VBR MP3", "MP3", "Flac", "FLAC", "24bit Flac", "WAVE", "AIFF"}


@dataclass
class AggregatedTrack:
    index: int
    title: str | None
    filename: str
    duration: str | None
    size: str | None
    stream_url: str


@dataclass
class AggregatedRecording:
    identifier: str
    source_quality: SourceQuality
    source: str | None
    taper: str | None
    lineage: str | None
    downloads: int
    tracks: list[AggregatedTrack] = field(default_factory=list)


@dataclass
class AggregatedConcert:
    id: str
    canonical_artist: str
    display_artist: str
    date: str
    date_precision: str  # "day" | "year"
    canonical_venue: str
    display_venue: str | None
    location: str | None
    recordings: list[AggregatedRecording] = field(default_factory=list)
    preferred_recording_id: str = ""
    aggregated_at: float = 0.0


def _parse_date(raw: str | None) -> tuple[str, str] | None:
    """Return (date, precision) or None if unparseable."""
    if not raw:
        return None
    d = raw.strip()[:10]
    if _DATE_FULL.match(d):
        return (d, "day")
    y = raw.strip()[:4]
    if _DATE_YEAR.match(y):
        return (y, "year")
    return None


def _concert_id(canonical_artist: str, date: str, canonical_venue: str) -> str:
    key = f"{canonical_artist}|{date}|{canonical_venue}"
    return str(uuid.uuid5(_NAMESPACE, key))


def _build_tracks(item: IAItem) -> list[AggregatedTrack]:
    tracks: list[AggregatedTrack] = []
    identifier = item.metadata.identifier
    idx = 0
    for f in item.files:
        if f.format not in _PLAYABLE_FORMATS:
            continue
        stream_url = f"https://archive.org/download/{identifier}/{f.name}"
        tracks.append(AggregatedTrack(
            index=idx,
            title=f.title,
            filename=f.name,
            duration=f.length,
            size=f.size,
            stream_url=stream_url,
        ))
        idx += 1
    return tracks


def _pick_preferred(recordings: list[AggregatedRecording]) -> str:
    """Best SourceQuality → most tracks → highest downloads."""
    if not recordings:
        return ""
    return min(
        recordings,
        key=lambda r: (r.source_quality.value, -len(r.tracks), -r.downloads),
    ).identifier


def aggregate_items(
    canonical_artist: str,
    disp_artist: str,
    search_items: list[IASearchItem],
    fetched_items: dict[str, IAItem],
) -> list[AggregatedConcert]:
    """Group search items into concerts. Items with metadata get full tracks."""
    now = time.time()

    groups: dict[tuple[str, str, str], list[IASearchItem]] = {}
    item_dates: dict[str, tuple[str, str]] = {}

    for item in search_items:
        parsed = _parse_date(item.date)
        if parsed is None:
            continue
        date, precision = parsed
        item_dates[item.identifier] = (date, precision)
        venue_raw = ""
        if item.identifier in fetched_items:
            meta = fetched_items[item.identifier].metadata
            venue_raw = meta.venue or ""
        venue_key = canonical_venue_key(venue_raw)
        group_key = (date, precision, venue_key)
        groups.setdefault(group_key, []).append(item)

    # Second pass: for items without fetched metadata, try to cluster them
    # with items that do have venue info from the same date
    for (date, precision, venue_key), items in list(groups.items()):
        if venue_key:
            continue
        # Items with no venue info — check if there's a same-date group with venue
        existing_with_venue = [
            k for k in groups if k[0] == date and k[1] == precision and k[2]
        ]
        if len(existing_with_venue) == 1:
            target = existing_with_venue[0]
            groups[target].extend(items)
            del groups[(date, precision, venue_key)]

    concerts: list[AggregatedConcert] = []
    for (date, precision, venue_key), items in groups.items():
        # Collect venue names for display from fetched items
        raw_venues: list[str] = []
        location: str | None = None
        for item in items:
            if item.identifier in fetched_items:
                meta = fetched_items[item.identifier].metadata
                if meta.venue:
                    raw_venues.append(meta.venue)
                if meta.coverage and not location:
                    location = meta.coverage

        disp_venue = display_venue(raw_venues) if raw_venues else None

        recordings: list[AggregatedRecording] = []
        for item in items:
            if item.identifier in fetched_items:
                ia_item = fetched_items[item.identifier]
                meta = ia_item.metadata
                sq = parse_source_quality(meta.source, meta.description, meta.identifier)
                tracks = _build_tracks(ia_item)
            else:
                sq = SourceQuality.UNKNOWN
                tracks = []

            recordings.append(AggregatedRecording(
                identifier=item.identifier,
                source_quality=sq,
                source=fetched_items[item.identifier].metadata.source if item.identifier in fetched_items else None,
                taper=fetched_items[item.identifier].metadata.taper if item.identifier in fetched_items else None,
                lineage=fetched_items[item.identifier].metadata.lineage if item.identifier in fetched_items else None,
                downloads=item.downloads,
                tracks=tracks,
            ))

        # Sort recordings best-first
        recordings.sort(key=lambda r: (r.source_quality.value, -len(r.tracks), -r.downloads))

        concert_id = _concert_id(canonical_artist, date, venue_key)
        concerts.append(AggregatedConcert(
            id=concert_id,
            canonical_artist=canonical_artist,
            display_artist=disp_artist,
            date=date,
            date_precision=precision,
            canonical_venue=venue_key,
            display_venue=disp_venue,
            location=location,
            recordings=recordings,
            preferred_recording_id=_pick_preferred(recordings),
            aggregated_at=now,
        ))

    concerts.sort(key=lambda c: c.date)
    return concerts
