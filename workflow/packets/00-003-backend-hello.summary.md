# Summary: 00-003-backend-hello

**Status:** Complete  
**Date:** 2026-05-16

## What was delivered

- `backend/main.py` — FastAPI app with lifespan-based logging setup; `GET /health` returns `{"status": "ok"}`.
- `backend/core/config.py` — `Settings` (pydantic-settings `BaseSettings`) with `TAPESCRAPE_` env prefix; fields: `base_url`, `database_url`, `ia_base_url`, `api_secret`, `ia_rate_limit`. Module-level `settings` singleton.
- `backend/core/http_client.py` — `IAClient`: single shared `httpx.AsyncClient` targeted at IA, async rate-limiter (token-bucket style with `asyncio.Lock`), request logging. No other module calls httpx directly.
- `backend/core/logging.py` — `setup_logging()` (stdout, timestamp+level+name formatter) and `get_logger(name)` wrapper.
- `backend/pyproject.toml` — deps: fastapi, uvicorn[standard], httpx, pydantic, pydantic-settings; dev: pytest, pytest-asyncio, anyio. `live_ia` marker registered; `asyncio_mode = auto`.
- `backend/tests/test_health.py` — TestClient test; 1 test passes, no live IA call.

## Running

```
# from repo root
uvicorn backend.main:app --reload
python -m pytest backend/tests/
```

## Deviations

- **No editable install (`pip install -e`)** — `pyproject.toml` lives inside `backend/`, so specifying `packages = ["backend"]` pointed setuptools at a non-existent `backend/backend/`. Removed `[tool.setuptools]` section; deps installed directly via `pip install`. Running pytest and uvicorn from the repo root with the default Python path works because `backend` is a package relative to the repo root. If a venv is added later, install with `pip install -r` from a requirements file generated from pyproject.toml.
