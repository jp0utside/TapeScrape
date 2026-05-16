from contextlib import asynccontextmanager

from fastapi import FastAPI

from backend.core.logging import setup_logging


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging()
    yield


app = FastAPI(title="TapeScrape", lifespan=lifespan)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
