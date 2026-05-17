import asyncio
import time

import httpx

from backend.core.http_client import IAClient


class _RecordingTransport(httpx.AsyncBaseTransport):
    """Records the wall-clock time each request is sent and sleeps `delay`
    seconds inside the (async) request, with no network."""

    def __init__(self, delay: float) -> None:
        self.delay = delay
        self.send_times: list[float] = []

    async def handle_async_request(self, request: httpx.Request) -> httpx.Response:
        self.send_times.append(time.monotonic())
        await asyncio.sleep(self.delay)
        return httpx.Response(200, json={"ok": True})


def _client_with(transport: _RecordingTransport, min_interval: float) -> IAClient:
    ia = IAClient()
    ia._client = httpx.AsyncClient(transport=transport, base_url="http://test")
    ia._min_interval = min_interval
    return ia


async def test_requests_are_rate_limited():
    """Successive sends are spaced by at least the configured interval."""
    interval = 0.05
    transport = _RecordingTransport(delay=0.0)
    ia = _client_with(transport, interval)
    try:
        await asyncio.gather(*(ia.get("/x") for _ in range(5)))
    finally:
        await ia._client.aclose()

    sends = sorted(transport.send_times)
    gaps = [b - a for a, b in zip(sends, sends[1:])]
    assert len(gaps) == 4
    # Allow modest scheduler jitter below the nominal interval.
    assert all(g >= interval * 0.8 for g in gaps), gaps


async def test_lock_not_held_across_sleep_or_http_call():
    """The rate-limiter lock must not serialize concurrent callers across the
    sleep + HTTP call. With the lock held across both (the old bug), N calls
    take ~N*(interval+delay); fixed, they pipeline to ~(N-1)*interval+delay.
    """
    # HTTP delay >> rate-limit interval, so "lock held across the HTTP call"
    # (the F1-5 regression) is sharply separable from the fixed behaviour.
    n = 5
    interval = 0.02
    delay = 0.10
    transport = _RecordingTransport(delay=delay)
    ia = _client_with(transport, interval)

    start = time.monotonic()
    try:
        await asyncio.gather(*(ia.get("/x") for _ in range(n)))
    finally:
        await ia._client.aclose()
    elapsed = time.monotonic() - start

    serialized = n * delay  # ~0.50s if the lock spans the HTTP call
    pipelined = (n - 1) * interval + delay  # ~0.18s when it does not
    assert elapsed < (serialized + pipelined) / 2, (
        f"elapsed={elapsed:.3f}s suggests the lock serializes the HTTP call "
        f"(serialized≈{serialized:.3f}s, pipelined≈{pipelined:.3f}s)"
    )


async def test_get_raises_for_status():
    def _404(request: httpx.Request) -> httpx.Response:
        return httpx.Response(404)

    ia = IAClient()
    ia._client = httpx.AsyncClient(
        transport=httpx.MockTransport(_404), base_url="http://test"
    )
    ia._min_interval = 0.0
    try:
        try:
            await ia.get("/missing")
            raised = False
        except httpx.HTTPStatusError:
            raised = True
    finally:
        await ia._client.aclose()
    assert raised
