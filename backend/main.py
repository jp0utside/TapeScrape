from contextlib import asynccontextmanager

from fastapi import FastAPI

from backend.core.cache import MetadataCache, SearchCache
from backend.core.config import settings
from backend.core.http_client import IAClient
from backend.core.logging import setup_logging
from backend.routes.concerts import router as concerts_router
from backend.routes.search import router as search_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging()
    app.state.ia_client = IAClient()
    app.state.metadata_cache = MetadataCache(settings.cache_db_path)
    app.state.search_cache = SearchCache(settings.cache_db_path)
    try:
        yield
    finally:
        await app.state.ia_client.aclose()


app = FastAPI(title="TapeScrape", lifespan=lifespan)

app.include_router(concerts_router)
app.include_router(search_router)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
