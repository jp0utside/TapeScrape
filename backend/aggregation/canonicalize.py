"""Canonical artist key — the load-bearing aggregation primitive.

Implements `docs/design/01-INTERNET-ARCHIVE.md` §5.1. Pure functions only
(no I/O) so the grouping heuristics stay independently testable; the whole
point of server-side aggregation is that these rules will be wrong on real
data and need tuning without an app release.
"""

import re

# Hand-curated, append-only alias map for high-traffic exceptions only.
# Keys are already in normalized (post-_normalize) form. Grow from real
# data evidence — never speculatively (CLAUDE.md / CONVENTIONS discipline).
_ARTIST_ALIASES: dict[str, str] = {
    "jgb": "jerry garcia band",
}

_LEADING_THE = re.compile(r"^the\s+")
_TRAILING_THE = re.compile(r",\s*the\s*$")
_CONNECTORS = re.compile(r"\s*[&+]\s*")
_AND_SPACES = re.compile(r"\s+and\s+")
_PUNCT = re.compile(r"[^a-z0-9 ]+")
_WS = re.compile(r"\s+")


def _normalize(raw: str) -> str:
    s = raw.strip().lower()
    s = _LEADING_THE.sub("", s)
    s = _TRAILING_THE.sub("", s)
    # Connectors must collapse BEFORE punctuation is stripped, or "&"/"+"
    # would vanish and "x and y" / "x & y" would split into different keys.
    s = _CONNECTORS.sub(" and ", s)
    s = _AND_SPACES.sub(" and ", s)
    s = _PUNCT.sub("", s)
    s = _WS.sub(" ", s).strip()
    return s


def canonical_artist_key(raw: str) -> str:
    """Group key for an IA `creator` string. Empty in → empty out."""
    if not raw:
        return ""
    normalized = _normalize(raw)
    return _ARTIST_ALIASES.get(normalized, normalized)


def display_artist(raw_names: list[str]) -> str:
    """Most common original casing among grouped raw names; ties → first seen."""
    counts: dict[str, int] = {}
    order: list[str] = []
    for name in raw_names:
        if name not in counts:
            counts[name] = 0
            order.append(name)
        counts[name] += 1
    if not order:
        return ""
    # `max` returns the first element reaching the maximum in iteration
    # order, so first-seen wins ties.
    return max(order, key=lambda n: counts[n])
