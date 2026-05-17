from backend.core.http_client import IAClient
from backend.models.ia import IAFile, IAItem, IAItemMetadata


async def get_item_metadata(client: IAClient, identifier: str) -> IAItem:
    response = await client.get(f"/metadata/{identifier}")
    data = response.json()

    return IAItem.model_validate(data)
