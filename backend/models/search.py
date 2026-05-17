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
