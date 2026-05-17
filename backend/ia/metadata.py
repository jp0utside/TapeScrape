from backend.core.http_client import IAClient
from backend.models.ia import IAFile, IAItem, IAItemMetadata

_client = IAClient()


async def get_item_metadata(identifier: str) -> IAItem:
    response = await _client.get(f"/metadata/{identifier}")
    data = response.json()

    return IAItem.model_validate(data)
