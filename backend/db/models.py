"""SQL table definitions for persisted concert aggregation.

Plain SQL CREATE TABLE statements — consistent with the existing cache pattern
(raw sqlite3, no ORM). Tables live in the shared cache_db_path SQLite file.
"""

CONCERTS_TABLE = """
CREATE TABLE IF NOT EXISTS concerts (
    id                      TEXT PRIMARY KEY,
    canonical_artist        TEXT NOT NULL,
    display_artist          TEXT NOT NULL,
    date                    TEXT NOT NULL,
    date_precision          TEXT NOT NULL,
    canonical_venue         TEXT NOT NULL DEFAULT '',
    display_venue           TEXT,
    location                TEXT,
    preferred_recording_id  TEXT NOT NULL DEFAULT '',
    aggregated_at           REAL NOT NULL
)
"""

RECORDINGS_TABLE = """
CREATE TABLE IF NOT EXISTS recordings (
    identifier      TEXT PRIMARY KEY,
    concert_id      TEXT NOT NULL REFERENCES concerts(id) ON DELETE CASCADE,
    source_quality  INTEGER NOT NULL,
    source          TEXT,
    taper           TEXT,
    lineage         TEXT,
    downloads       INTEGER NOT NULL DEFAULT 0,
    sort_order      INTEGER NOT NULL DEFAULT 0
)
"""

TRACKS_TABLE = """
CREATE TABLE IF NOT EXISTS tracks (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    recording_id    TEXT NOT NULL REFERENCES recordings(identifier) ON DELETE CASCADE,
    idx             INTEGER NOT NULL,
    title           TEXT,
    filename        TEXT NOT NULL,
    duration        TEXT,
    size            TEXT,
    stream_url      TEXT NOT NULL
)
"""

ALL_TABLES = [CONCERTS_TABLE, RECORDINGS_TABLE, TRACKS_TABLE]
