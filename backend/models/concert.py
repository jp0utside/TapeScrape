from pydantic import BaseModel


class TrackResponse(BaseModel):
    index: int
    title: str | None
    filename: str
    duration: str | None  # raw string from IA; parsed to seconds in Phase 2
    stream_url: str        # opaque: https://archive.org/download/<id>/<filename>


class RecordingResponse(BaseModel):
    identifier: str
    source_quality: str    # SourceQuality name: "SBD" | "MTX" | "AUD" | "FM" | "UNKNOWN"
    source: str | None
    taper: str | None
    lineage: str | None
    download_count: int
    tracks: list[TrackResponse]


class ConcertListItem(BaseModel):
    id: str
    display_artist: str
    date: str
    date_precision: str    # "day" | "year"
    display_venue: str | None
    location: str | None
    recording_count: int
    preferred_recording_id: str


class ConcertListResponse(BaseModel):
    concerts: list[ConcertListItem]
    total: int
    page: int
    page_size: int


class ConcertDetailResponse(BaseModel):
    id: str
    artist: str
    date: str
    venue: str | None
    location: str | None
    preferred_recording_id: str
    recordings: list[RecordingResponse]
