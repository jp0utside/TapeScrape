from backend.core.cache import MetadataCache
from backend.core.http_client import IAClient
from backend.models.ia import IAItem


async def get_item_metadata(
    client: IAClient, identifier: str, cache: MetadataCache
) -> IAItem:
    cached = await cache.get(identifier)
    if cached is not None:
        return IAItem.model_validate(cached)
    response = await client.get(f"/metadata/{identifier}")
    data = response.json()
    await cache.set(identifier, data)
    return IAItem.model_validate(data)
