from pathlib import Path

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    base_url: str = "http://localhost:8000"
    database_url: str = "sqlite+aiosqlite:///./tapescrape.db"
    ia_base_url: str = "https://archive.org"
    api_secret: str | None = None
    ia_rate_limit: float = 1.0  # max requests per second to IA
    cache_db_path: Path = Path("./tapescrape_cache.db")
    search_cache_ttl_seconds: int = 1800  # ~30 min; browse data goes stale

    model_config = {"env_prefix": "TAPESCRAPE_"}


settings = Settings()
