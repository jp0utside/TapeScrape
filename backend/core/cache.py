import json
import sqlite3
import time
from pathlib import Path


class MetadataCache:
    """SQLite-backed cache for raw IA Metadata API responses.

    Uses stdlib sqlite3 (sync) — acceptable at Phase 1 single-user scale.
    The async interface is kept so callers can await without change in Phase 2.
    """

    def __init__(self, db_path: Path) -> None:
        self._db_path = str(db_path)
        self._init_db()

    def _init_db(self) -> None:
        with sqlite3.connect(self._db_path) as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS metadata_cache (
                    identifier TEXT PRIMARY KEY,
                    data       TEXT    NOT NULL,
                    expires_at REAL    NOT NULL
                )
                """
            )
            conn.commit()

    async def get(self, identifier: str) -> dict | None:
        with sqlite3.connect(self._db_path) as conn:
            row = conn.execute(
                "SELECT data, expires_at FROM metadata_cache WHERE identifier = ?",
                (identifier,),
            ).fetchone()
        if row is None:
            return None
        data, expires_at = row
        if time.time() > expires_at:
            return None
        return json.loads(data)

    async def set(
        self, identifier: str, data: dict, ttl_seconds: int = 86400
    ) -> None:
        expires_at = time.time() + ttl_seconds
        with sqlite3.connect(self._db_path) as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO metadata_cache (identifier, data, expires_at)
                VALUES (?, ?, ?)
                """,
                (identifier, json.dumps(data), expires_at),
            )
            conn.commit()


class SearchCache:
    """SQLite-backed cache for raw IA Advanced Search responses.

    Same shape and sync-stdlib rationale as MetadataCache, but a distinct
    table (`search_cache`) keyed by a hash of the normalized query — TTL is
    short (~30 min) because browse data goes stale, vs ~24 h for immutable
    item metadata (`00-ARCHITECTURE.md` §6).
    """

    def __init__(self, db_path: Path) -> None:
        self._db_path = str(db_path)
        self._init_db()

    def _init_db(self) -> None:
        with sqlite3.connect(self._db_path) as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS search_cache (
                    cache_key  TEXT PRIMARY KEY,
                    data       TEXT NOT NULL,
                    expires_at REAL NOT NULL
                )
                """
            )
            conn.commit()

    async def get(self, key: str) -> dict | None:
        with sqlite3.connect(self._db_path) as conn:
            row = conn.execute(
                "SELECT data, expires_at FROM search_cache WHERE cache_key = ?",
                (key,),
            ).fetchone()
        if row is None:
            return None
        data, expires_at = row
        if time.time() > expires_at:
            return None
        return json.loads(data)

    async def set(self, key: str, data: dict, ttl_seconds: int = 1800) -> None:
        expires_at = time.time() + ttl_seconds
        with sqlite3.connect(self._db_path) as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO search_cache (cache_key, data, expires_at)
                VALUES (?, ?, ?)
                """,
                (key, json.dumps(data), expires_at),
            )
            conn.commit()
