import json
from pathlib import Path

FIXTURES_DIR = Path(__file__).parent / "fixtures"


def load_fixture(filename: str) -> dict:
    return json.loads((FIXTURES_DIR / filename).read_text())
