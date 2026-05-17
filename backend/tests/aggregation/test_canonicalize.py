import pytest

from backend.aggregation.canonicalize import canonical_artist_key, display_artist


@pytest.mark.parametrize(
    "raw,expected",
    [
        # The §3.3 "Grateful Dead" variants must collapse to one key.
        ("Grateful Dead", "grateful dead"),
        ("The Grateful Dead", "grateful dead"),
        ("Grateful Dead, The", "grateful dead"),
        ("  grateful dead  ", "grateful dead"),
        # Casing.
        ("Phish", "phish"),
        ("phish", "phish"),
        # Connector normalization: &, +, and → " and ".
        ("Bob Weir & Ratdog", "bob weir and ratdog"),
        ("Bob Weir and Ratdog", "bob weir and ratdog"),
        ("Bob Weir + Ratdog", "bob weir and ratdog"),
        # Punctuation stripped.
        ("Phish!", "phish"),
        ("String Cheese Incident, The", "string cheese incident"),
        # Alias map (seeded with only the spec example).
        ("JGB", "jerry garcia band"),
        ("jgb", "jerry garcia band"),
        ("Jerry Garcia Band", "jerry garcia band"),
        # Empty in → empty out (creator can be absent on IA items).
        ("", ""),
        ("   ", ""),
    ],
)
def test_canonical_artist_key(raw: str, expected: str):
    assert canonical_artist_key(raw) == expected


def test_variants_share_one_key():
    keys = {
        canonical_artist_key(v)
        for v in ["Grateful Dead", "The Grateful Dead", "Grateful Dead, The"]
    }
    assert keys == {"grateful dead"}


def test_distinct_artists_do_not_collide():
    assert canonical_artist_key("Phish") != canonical_artist_key("Grateful Dead")


def test_display_artist_picks_most_common_casing():
    names = ["Grateful Dead", "Grateful Dead", "grateful dead", "The Grateful Dead"]
    assert display_artist(names) == "Grateful Dead"


def test_display_artist_ties_go_to_first_seen():
    names = ["The Grateful Dead", "Grateful Dead, The"]  # one each → tie
    assert display_artist(names) == "The Grateful Dead"


def test_display_artist_empty_is_empty():
    assert display_artist([]) == ""
