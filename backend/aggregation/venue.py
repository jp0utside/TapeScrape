"""Canonical venue key — token-set similarity clustering.

Fixes the raw-majority-vote bug from set-scrape where unnormalized strings
like "Madison Square Garden" / "MSG" / "MSG, NYC" split votes. Uses token-set
ratio (sorted token overlap / union) at ~0.85 threshold, plus an append-only
alias map for known exceptions.
"""

import re

_VENUE_ALIASES: dict[str, str] = {
    "msg": "madison square garden",
    "msg nyc": "madison square garden",
    "red rocks": "red rocks amphitheatre",
}

_PUNCT = re.compile(r"[^a-z0-9 ]+")
_WS = re.compile(r"\s+")


def _normalize_venue(raw: str) -> str:
    s = raw.strip().lower()
    s = _PUNCT.sub(" ", s)
    s = _WS.sub(" ", s).strip()
    return s


def _token_set_ratio(a: str, b: str) -> float:
    """Token-set similarity: size of intersection / size of union of token sets."""
    tokens_a = set(a.split())
    tokens_b = set(b.split())
    if not tokens_a and not tokens_b:
        return 1.0
    if not tokens_a or not tokens_b:
        return 0.0
    intersection = tokens_a & tokens_b
    union = tokens_a | tokens_b
    return len(intersection) / len(union)


_SIMILARITY_THRESHOLD = 0.85


def canonical_venue_key(raw: str) -> str:
    """Normalize a venue string to its canonical form."""
    if not raw:
        return ""
    normalized = _normalize_venue(raw)
    return _VENUE_ALIASES.get(normalized, normalized)


def cluster_venues(raw_names: list[str]) -> dict[str, list[str]]:
    """Group raw venue strings into clusters by token-set similarity.

    Returns {canonical_key: [original_raw_names_in_cluster]}.
    """
    clusters: list[tuple[str, list[str]]] = []

    for raw in raw_names:
        if not raw:
            continue
        normalized = _normalize_venue(raw)
        key = _VENUE_ALIASES.get(normalized, normalized)

        matched = False
        for i, (cluster_key, members) in enumerate(clusters):
            if key == cluster_key or _token_set_ratio(key, cluster_key) >= _SIMILARITY_THRESHOLD:
                members.append(raw)
                matched = True
                break

        if not matched:
            clusters.append((key, [raw]))

    return {key: members for key, members in clusters}


def display_venue(raw_names: list[str]) -> str | None:
    """Most common original casing among grouped raw venue names; ties → first seen."""
    if not raw_names:
        return None
    counts: dict[str, int] = {}
    order: list[str] = []
    for name in raw_names:
        if not name:
            continue
        if name not in counts:
            counts[name] = 0
            order.append(name)
        counts[name] += 1
    if not order:
        return None
    return max(order, key=lambda n: counts[n])
