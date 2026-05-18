import pytest
from unittest.mock import MagicMock

from backend.tests.helpers import load_fixture
from backend.ia.search import search_items
from backend.models.ia import IASearchResult


def _make_mock_response(data: dict) -> MagicMock:
    mock = MagicMock()
    mock.json.return_value = data
    mock.raise_for_status = MagicMock()
    return mock


def test_search_result_parses_fixture():
    fixture = load_fixture("gd1977-05-08_search.json")
    docs = fixture["response"]["docs"]
    total = fixture["response"]["numFound"]

    items_data = []
    for doc in docs:
        items_data.append(
            {
                "identifier": doc.get("identifier", ""),
                "title": doc.get("title", ""),
                "creator": doc.get("creator"),
                "date": doc.get("date"),
                "downloads": doc.get("downloads", 0),
            }
        )

    from backend.models.ia import IASearchItem

    items = [IASearchItem.model_validate(d) for d in items_data]
    result = IASearchResult(items=items, total=total)

    assert result.total == 8
    assert len(result.items) == 8


def test_search_item_fields():
    fixture = load_fixture("gd1977-05-08_search.json")
    doc = fixture["response"]["docs"][0]

    from backend.models.ia import IASearchItem

    item = IASearchItem.model_validate(doc)

    assert item.identifier
    assert item.identifier.startswith("gd")
    assert item.title
    assert item.creator == "Grateful Dead"
    assert item.date is not None
    assert item.downloads > 0


def test_search_items_missing_optional_fields():
    from backend.models.ia import IASearchItem

    item = IASearchItem.model_validate({"identifier": "test-id", "title": "Test Show"})
    assert item.creator is None
    assert item.date is None
    assert item.downloads == 0


@pytest.mark.asyncio
@pytest.mark.live_ia
async def test_search_items_live():
    from backend.core.http_client import IAClient

    ia_client = IAClient()
    try:
        result = await search_items(
            ia_client, creator="Grateful Dead", date="1977-05-08"
        )
    finally:
        await ia_client.aclose()
    assert result.total > 0
    assert len(result.items) > 0
    assert all(item.identifier for item in result.items)
