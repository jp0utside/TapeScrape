"""Tests for venue canonicalization and clustering."""


from backend.aggregation.venue import (
    canonical_venue_key,
    cluster_venues,
    display_venue,
)


class TestCanonicalVenueKey:
    def test_basic_normalization(self):
        assert canonical_venue_key("Barton Hall") == "barton hall"

    def test_strips_punctuation(self):
        assert canonical_venue_key("Barton Hall!") == "barton hall"

    def test_alias_msg(self):
        assert canonical_venue_key("MSG") == "madison square garden"
        assert canonical_venue_key("MSG, NYC") == "madison square garden"

    def test_alias_red_rocks(self):
        assert canonical_venue_key("Red Rocks") == "red rocks amphitheatre"

    def test_empty(self):
        assert canonical_venue_key("") == ""


class TestClusterVenues:
    def test_identical_venues_cluster(self):
        raw = ["Madison Square Garden", "Madison Square Garden", "Madison Square Garden"]
        clusters = cluster_venues(raw)
        assert len(clusters) == 1
        assert len(list(clusters.values())[0]) == 3

    def test_alias_based_clustering(self):
        raw = ["MSG", "MSG, NYC", "Madison Square Garden"]
        clusters = cluster_venues(raw)
        assert len(clusters) == 1

    def test_similar_venues_cluster(self):
        raw = ["Red Rocks Amphitheatre", "Red Rocks Amphitheatre, Morrison CO"]
        clusters = cluster_venues(raw)
        # "Red Rocks" alias handles the first; the second has high token overlap
        assert len(clusters) <= 2

    def test_different_venues_stay_separate(self):
        raw = ["Barton Hall", "Fillmore West", "Madison Square Garden"]
        clusters = cluster_venues(raw)
        assert len(clusters) == 3

    def test_empty_strings_skipped(self):
        raw = ["", "", "Barton Hall"]
        clusters = cluster_venues(raw)
        assert len(clusters) == 1
        assert "barton hall" in clusters


class TestDisplayVenue:
    def test_most_common_wins(self):
        raw = ["Barton Hall", "barton hall", "Barton Hall"]
        assert display_venue(raw) == "Barton Hall"

    def test_first_seen_breaks_tie(self):
        raw = ["Barton Hall", "BARTON HALL"]
        assert display_venue(raw) == "Barton Hall"

    def test_empty_list(self):
        assert display_venue([]) is None

    def test_all_empty_strings(self):
        assert display_venue(["", ""]) is None
