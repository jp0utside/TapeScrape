from pydantic import BaseModel, Field


class ArtistMatch(BaseModel):
    canonical_artist: str
    display_artist: str
    recording_count: int = Field(
        ...,
        description=(
            "Distinct IA items in THIS search response that map to this "
            "canonical artist. Pre-aggregation: NOT a catalog total."
        ),
    )


class ArtistSearchResponse(BaseModel):
    query: str
    type: str
    matches: list[ArtistMatch]


class TrackMatch(BaseModel):
    title: str | None
    filename: str
    duration: str | None
    stream_url: str
    recording_identifier: str
    concert_id: str
    artist: str
    date: str
    venue: str | None
    source_quality: str


class TrackSearchResponse(BaseModel):
    query: str
    type: str = "track"
    results: list[TrackMatch]
    total: int
