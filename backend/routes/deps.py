"""Shared FastAPI dependencies for the route layer.

Lives in `routes/` (not `core/`) because it needs `fastapi.Request`, and
CONVENTIONS §1 restricts `core/` to stdlib + Pydantic. Promoted here from
`routes/concerts.py` once a second route (`routes/search.py`) needed the
same injected client — the second-consumer trigger pre-registered in the
`01.5-001` summary.
"""

from fastapi import Request

from backend.core.cache import MetadataCache, SearchCache
from backend.core.http_client import IAClient


def get_ia_client(request: Request) -> IAClient:
    """The single IAClient built in the app lifespan (`main.py`)."""
    return request.app.state.ia_client


def get_metadata_cache(request: Request) -> MetadataCache:
    return request.app.state.metadata_cache


def get_search_cache(request: Request) -> SearchCache:
    return request.app.state.search_cache
