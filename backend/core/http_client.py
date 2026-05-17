import asyncio
import time

import httpx

from backend.core.config import settings
from backend.core.logging import get_logger

logger = get_logger(__name__)


class IAClient:
    """Single HTTP client for all Internet Archive calls.

    Rate-limited to settings.ia_rate_limit requests/second. Logs every request
    with URL and cache-hit status. No other module makes direct httpx calls.
    """

    def __init__(self) -> None:
        self._client = httpx.AsyncClient(
            base_url=settings.ia_base_url,
            timeout=30.0,
            follow_redirects=True,
        )
        self._min_interval = 1.0 / settings.ia_rate_limit
        self._last_request_at: float = 0.0
        self._lock = asyncio.Lock()

    async def get(
        self,
        path: str,
        params: dict | None = None,
        *,
        cache_hit: bool = False,
    ) -> httpx.Response:
        async with self._lock:
            scheduled = max(
                time.monotonic(), self._last_request_at + self._min_interval
            )
            self._last_request_at = scheduled

        delay = scheduled - time.monotonic()
        if delay > 0:
            await asyncio.sleep(delay)

        logger.info("ia_request url=%s%s cache_hit=%s", settings.ia_base_url, path, cache_hit)
        response = await self._client.get(path, params=params)
        response.raise_for_status()
        return response

    async def aclose(self) -> None:
        await self._client.aclose()
