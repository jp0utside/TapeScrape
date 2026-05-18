"""Tests for SourceQuality parsing."""

import pytest

from backend.aggregation.source_quality import SourceQuality, parse_source_quality


@pytest.mark.parametrize(
    "source,description,identifier,expected",
    [
        ("SBD > Master Reel > DAT", None, "gd1977-05-08.12345", SourceQuality.SBD),
        ("Soundboard", None, "gd1977-05-08.sbd.miller.12345", SourceQuality.SBD),
        (None, None, "gd1977-05-08.sbd.miller.12345.flac16", SourceQuality.SBD),
        ("AUD > DAT > CD", None, "gd1977-05-08.aud.12345", SourceQuality.AUD),
        (None, "Audience recording from the 5th row", "gd1977-05-08.12345", SourceQuality.AUD),
        ("Matrix (SBD + AUD)", None, "gd1977-05-08.mtx.12345", SourceQuality.MTX),
        (None, None, "gd1977-05-08.mtx.12345", SourceQuality.MTX),
        ("FM broadcast", None, "gd1977-05-08.12345", SourceQuality.FM),
        (None, "FM simulcast", "gd1977-05-08.12345", SourceQuality.FM),
        (None, None, "gd1977-05-08.12345", SourceQuality.UNKNOWN),
        ("", "", "gd1977-05-08.12345.flac16", SourceQuality.UNKNOWN),
    ],
)
def test_parse_source_quality(source, description, identifier, expected):
    assert parse_source_quality(source, description, identifier) == expected


def test_sbd_in_source_beats_aud_in_identifier():
    """source field is checked before identifier."""
    result = parse_source_quality("SBD > DAT", None, "gd1977-05-08.aud.12345")
    assert result == SourceQuality.SBD


def test_identifier_checked_before_description():
    result = parse_source_quality(None, "audience recording", "gd1977-05-08.sbd.12345")
    assert result == SourceQuality.SBD


def test_matrix_beats_sbd_in_same_field():
    """Matrix mentions SBD as a component but is classified as MTX."""
    result = parse_source_quality("Matrix (SBD + AUD)", None, "gd1977-05-08.12345")
    assert result == SourceQuality.MTX
