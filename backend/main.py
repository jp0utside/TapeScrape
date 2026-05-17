from contextlib import asynccontextmanager

from fastapi import FastAPI

from backend.core.logging import setup_logging
from backend.routes.concerts import router as concerts_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging()
    yield


app = FastAPI(title="TapeScrape", lifespan=lifespan)

app.include_router(concerts_router)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
