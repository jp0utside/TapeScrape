from backend.core.http_client import IAClient
from backend.models.ia import IASearchItem, IASearchResult

_SEARCH_FIELDS = ["identifier", "title", "creator", "date", "downloads"]
_BASE_QUERY = "collection:etree AND NOT collection:stream_only"


async def search_items(
    client: IAClient,
    *,
    query: str | None = None,
    creator: str | None = None,
    date: str | None = None,
    rows: int = 50,
    page: int = 1,
) -> IASearchResult:
    parts = [_BASE_QUERY]
    if creator:
        parts.append(f'creator:"{creator}"')
    if date:
        parts.append(f"date:{date}")
    if query:
        parts.append(query)

    params: dict = {
        "q": " AND ".join(parts),
        "fl[]": _SEARCH_FIELDS,
        "rows": rows,
        "page": page,
        "output": "json",
    }

    response = await client.get("/advancedsearch.php", params=params)
    data = response.json()
    response_body = data.get("response", {})
    docs = response_body.get("docs", [])
    total = response_body.get("numFound", 0)

    items = [IASearchItem.model_validate(doc) for doc in docs]
    return IASearchResult(items=items, total=total)
