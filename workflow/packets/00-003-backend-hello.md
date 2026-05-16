# Task Packet: FastAPI backend skeleton

**Packet ID:** 00-003-backend-hello
**Phase:** 0
**Created:** 2026-05-16
**Status:** READY
**Auto-proceed:** true
**High-risk:** false

## Goal

Create the Python/FastAPI backend project with the `core/` module structure, one stub
health-check route, and local `uvicorn` execution. After this packet the backend runs
locally and has the scaffolding future packets drop real endpoints into.

## Acceptance criteria

- [ ] Backend lives at `backend/` in the repo root
- [ ] `uvicorn backend.main:app` starts the server on `localhost:8000`
- [ ] `GET /health` returns `{"status": "ok"}` (200)
- [ ] `core/config.py` exists: settings via env vars prefixed `TAPESCRAPE_`, includes
      `BASE_URL`, `DATABASE_URL` (defaults to local SQLite path), `IA_BASE_URL`,
      optional `API_SECRET`
- [ ] `core/http_client.py` exists: a single shared `httpx.AsyncClient` with rate-limit
      and logging hooks (stub/minimal — real caching in Phase 1)
- [ ] `core/logging.py` exists: structured logger setup (stdlib `logging`, JSON optional)
- [ ] `pytest` passes with no live IA calls (the one test hits `/health` via TestClient)
- [ ] `requirements.txt` (or `pyproject.toml` with deps) pins FastAPI, uvicorn, httpx,
      pydantic, pytest, httpx (test)

## Read first

- `docs/design/00-ARCHITECTURE.md` § 2, 5 — what the backend does/doesn't do, stack
- `workflow/CONVENTIONS.md` § 1, 2, 5, 8 — module boundaries, network, async, config

## Files expected to change

- `backend/__init__.py` — package marker
- `backend/main.py` — FastAPI app, health route, lifespan
- `backend/core/__init__.py`
- `backend/core/config.py` — settings (Pydantic BaseSettings or dataclass + env)
- `backend/core/http_client.py` — shared async HTTP client
- `backend/core/logging.py` — logging setup
- `backend/tests/__init__.py`
- `backend/tests/test_health.py` — TestClient test for `/health`
- `backend/pyproject.toml` or `backend/requirements.txt` — dependencies

## Interface sketch

```python
# core/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    base_url: str = "http://localhost:8000"
    database_url: str = "sqlite+aiosqlite:///./tapescrape.db"
    ia_base_url: str = "https://archive.org"
    api_secret: str | None = None
    ia_rate_limit: float = 1.0  # requests per second

    model_config = {"env_prefix": "TAPESCRAPE_"}

# core/http_client.py
import httpx

class IAClient:
    """Single HTTP client for all Internet Archive calls.
    Rate-limited, logged. No other module makes direct httpx calls."""
    async def get(self, path: str, params: dict | None = None) -> httpx.Response: ...

# main.py
from fastapi import FastAPI

app = FastAPI(title="TapeScrape")

@app.get("/health")
async def health():
    return {"status": "ok"}
```

## Constraints to preserve

- See `workflow/CONVENTIONS.md` (always applicable)
- See `CLAUDE.md` § "Core constraints" (always applicable)
- All external HTTP through `core/http_client.py` — no ad-hoc `httpx.get` in routes
- `async def` for routes and I/O functions
- Backend writes only to its SQLite DB and configured cache directory
- Do NOT deploy — local `uvicorn` only for Phase 0

## Tests

- REQUIRED
- `backend/tests/test_health.py` — `GET /health` returns 200 + expected body via
  `httpx.AsyncClient` or FastAPI `TestClient`

## Known ambiguities / open questions

- Whether to use `pyproject.toml` (modern) vs `requirements.txt` (simpler). Either is
  fine; prefer `pyproject.toml` with a `[project]` table if the tooling is comfortable.
- The exact rate-limiting mechanism (token bucket, simple sleep) can be minimal for now —
  real tuning happens when live IA calls start in Phase 1.

## Out of scope

- Real IA endpoints (search, metadata) — Phase 1
- SQLite schema / migrations / ORM setup — Phase 1
- Real caching layer — Phase 1
- Deployment to any host — Phase 1 (D2b)
- The optional API-secret middleware — later (it's a config flag, not blocking)
- Any iOS client changes

## Summary output path

`workflow/packets/00-003-backend-hello.summary.md`
