import pytest


def pytest_configure(config):
    config.addinivalue_line(
        "markers",
        "live_ia: marks tests that make real Internet Archive calls (skipped by default)",
    )


def pytest_collection_modifyitems(config, items):
    if not config.getoption("-m", default="") == "live_ia":
        skip_live = pytest.mark.skip(reason="live IA call — run with -m live_ia")
        for item in items:
            if item.get_closest_marker("live_ia"):
                item.add_marker(skip_live)
