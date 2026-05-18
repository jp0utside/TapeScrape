"""Persistence for aggregated concerts — read/write to SQLite.

Uses the same cache_db_path as MetadataCache/SearchCache. Plain sqlite3,
consistent with the Phase 1 pattern. Tables created on first access.
"""

import sqlite3
import time
from pathlib import Path

from backend.aggregation.aggregate import (
    AggregatedConcert,
    AggregatedRecording,
    AggregatedTrack,
)
from backend.aggregation.source_quality import SourceQuality
from backend.db.models import ALL_TABLES


def _ensure_tables(db_path: str) -> None:
    with sqlite3.connect(db_path) as conn:
        for ddl in ALL_TABLES:
            conn.execute(ddl)
        conn.commit()


def save_aggregation(db_path: Path, concerts: list[AggregatedConcert]) -> None:
    """Persist concerts, replacing any existing data for the same artist."""
    path_str = str(db_path)
    _ensure_tables(path_str)

    if not concerts:
        return

    canonical_artist = concerts[0].canonical_artist

    with sqlite3.connect(path_str) as conn:
        # Delete existing data for this artist
        existing_ids = conn.execute(
            "SELECT id FROM concerts WHERE canonical_artist = ?",
            (canonical_artist,),
        ).fetchall()
        for (cid,) in existing_ids:
            conn.execute("DELETE FROM tracks WHERE recording_id IN (SELECT identifier FROM recordings WHERE concert_id = ?)", (cid,))
            conn.execute("DELETE FROM recordings WHERE concert_id = ?", (cid,))
        conn.execute("DELETE FROM concerts WHERE canonical_artist = ?", (canonical_artist,))

        for concert in concerts:
            conn.execute(
                """INSERT INTO concerts (id, canonical_artist, display_artist, date,
                   date_precision, canonical_venue, display_venue, location,
                   preferred_recording_id, aggregated_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    concert.id,
                    concert.canonical_artist,
                    concert.display_artist,
                    concert.date,
                    concert.date_precision,
                    concert.canonical_venue,
                    concert.display_venue,
                    concert.location,
                    concert.preferred_recording_id,
                    concert.aggregated_at,
                ),
            )

            for order, rec in enumerate(concert.recordings):
                conn.execute(
                    """INSERT INTO recordings (identifier, concert_id, source_quality,
                       source, taper, lineage, downloads, sort_order)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                    (
                        rec.identifier,
                        concert.id,
                        rec.source_quality.value,
                        rec.source,
                        rec.taper,
                        rec.lineage,
                        rec.downloads,
                        order,
                    ),
                )

                for track in rec.tracks:
                    conn.execute(
                        """INSERT INTO tracks (recording_id, idx, title, filename,
                           duration, size, stream_url)
                           VALUES (?, ?, ?, ?, ?, ?, ?)""",
                        (
                            rec.identifier,
                            track.index,
                            track.title,
                            track.filename,
                            track.duration,
                            track.size,
                            track.stream_url,
                        ),
                    )

        conn.commit()


def get_concerts_for_artist(
    db_path: Path, canonical_artist: str
) -> list[AggregatedConcert]:
    """Load all persisted concerts for an artist, with recordings and tracks."""
    path_str = str(db_path)
    _ensure_tables(path_str)

    with sqlite3.connect(path_str) as conn:
        conn.row_factory = sqlite3.Row
        concert_rows = conn.execute(
            "SELECT * FROM concerts WHERE canonical_artist = ? ORDER BY date",
            (canonical_artist,),
        ).fetchall()

        concerts: list[AggregatedConcert] = []
        for crow in concert_rows:
            rec_rows = conn.execute(
                "SELECT * FROM recordings WHERE concert_id = ? ORDER BY sort_order",
                (crow["id"],),
            ).fetchall()

            recordings: list[AggregatedRecording] = []
            for rrow in rec_rows:
                track_rows = conn.execute(
                    "SELECT * FROM tracks WHERE recording_id = ? ORDER BY idx",
                    (rrow["identifier"],),
                ).fetchall()

                tracks = [
                    AggregatedTrack(
                        index=t["idx"],
                        title=t["title"],
                        filename=t["filename"],
                        duration=t["duration"],
                        size=t["size"],
                        stream_url=t["stream_url"],
                    )
                    for t in track_rows
                ]

                recordings.append(AggregatedRecording(
                    identifier=rrow["identifier"],
                    source_quality=SourceQuality(rrow["source_quality"]),
                    source=rrow["source"],
                    taper=rrow["taper"],
                    lineage=rrow["lineage"],
                    downloads=rrow["downloads"],
                    tracks=tracks,
                ))

            concerts.append(AggregatedConcert(
                id=crow["id"],
                canonical_artist=crow["canonical_artist"],
                display_artist=crow["display_artist"],
                date=crow["date"],
                date_precision=crow["date_precision"],
                canonical_venue=crow["canonical_venue"],
                display_venue=crow["display_venue"],
                location=crow["location"],
                recordings=recordings,
                preferred_recording_id=crow["preferred_recording_id"],
                aggregated_at=crow["aggregated_at"],
            ))

        return concerts


def get_concert_by_id(db_path: Path, concert_id: str) -> AggregatedConcert | None:
    """Load a single concert by its opaque ID."""
    path_str = str(db_path)
    _ensure_tables(path_str)

    with sqlite3.connect(path_str) as conn:
        conn.row_factory = sqlite3.Row
        crow = conn.execute(
            "SELECT * FROM concerts WHERE id = ?", (concert_id,)
        ).fetchone()
        if crow is None:
            return None

        rec_rows = conn.execute(
            "SELECT * FROM recordings WHERE concert_id = ? ORDER BY sort_order",
            (crow["id"],),
        ).fetchall()

        recordings: list[AggregatedRecording] = []
        for rrow in rec_rows:
            track_rows = conn.execute(
                "SELECT * FROM tracks WHERE recording_id = ? ORDER BY idx",
                (rrow["identifier"],),
            ).fetchall()

            tracks = [
                AggregatedTrack(
                    index=t["idx"],
                    title=t["title"],
                    filename=t["filename"],
                    duration=t["duration"],
                    size=t["size"],
                    stream_url=t["stream_url"],
                )
                for t in track_rows
            ]

            recordings.append(AggregatedRecording(
                identifier=rrow["identifier"],
                source_quality=SourceQuality(rrow["source_quality"]),
                source=rrow["source"],
                taper=rrow["taper"],
                lineage=rrow["lineage"],
                downloads=rrow["downloads"],
                tracks=tracks,
            ))

        return AggregatedConcert(
            id=crow["id"],
            canonical_artist=crow["canonical_artist"],
            display_artist=crow["display_artist"],
            date=crow["date"],
            date_precision=crow["date_precision"],
            canonical_venue=crow["canonical_venue"],
            display_venue=crow["display_venue"],
            location=crow["location"],
            recordings=recordings,
            preferred_recording_id=crow["preferred_recording_id"],
            aggregated_at=crow["aggregated_at"],
        )


def get_aggregation_age(db_path: Path, canonical_artist: str) -> float | None:
    """Seconds since last aggregation for this artist, or None if never."""
    path_str = str(db_path)
    _ensure_tables(path_str)

    with sqlite3.connect(path_str) as conn:
        row = conn.execute(
            "SELECT MAX(aggregated_at) FROM concerts WHERE canonical_artist = ?",
            (canonical_artist,),
        ).fetchone()
        if row is None or row[0] is None:
            return None
        return time.time() - row[0]
