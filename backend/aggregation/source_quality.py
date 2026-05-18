"""SourceQuality classification — parse recording quality from IA metadata.

Implements `docs/design/01-INTERNET-ARCHIVE.md` §5.6 and `02-DATA-MODEL.md` §1.
Parses from the item's `source` field, `description`, and identifier tokens.
First match wins.
"""

import re
from enum import IntEnum


class SourceQuality(IntEnum):
    SBD = 0
    MTX = 1
    AUD = 2
    FM = 3
    UNKNOWN = 4


_MTX_PATTERN = re.compile(r"\b(?:mtx|matrix)\b", re.IGNORECASE)
_SBD_PATTERN = re.compile(r"\bsbd\b", re.IGNORECASE)
_AUD_PATTERN = re.compile(r"\b(?:aud|audience)\b", re.IGNORECASE)
_FM_PATTERN = re.compile(r"\bfm\b", re.IGNORECASE)

# Order matters: MTX checked before SBD because "Matrix (SBD + AUD)" is a
# matrix recording, not a soundboard.
_PATTERNS: list[tuple[re.Pattern, SourceQuality]] = [
    (_MTX_PATTERN, SourceQuality.MTX),
    (_SBD_PATTERN, SourceQuality.SBD),
    (_AUD_PATTERN, SourceQuality.AUD),
    (_FM_PATTERN, SourceQuality.FM),
]


def parse_source_quality(
    source: str | None,
    description: str | None,
    identifier: str,
) -> SourceQuality:
    """Classify a recording's source quality. First match wins across fields."""
    for text in (source, identifier, description):
        if not text:
            continue
        for pattern, quality in _PATTERNS:
            if pattern.search(text):
                return quality
    return SourceQuality.UNKNOWN
