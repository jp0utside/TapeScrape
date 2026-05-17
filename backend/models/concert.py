from pydantic import BaseModel


class TrackResponse(BaseModel):
    index: int
    title: str | None
    filename: str
    duration: str | None  # raw string from IA; parsed to seconds in Phase 2
    stream_url: str        # opaque: https://archive.org/download/<id>/<filename>


class RecordingResponse(BaseModel):
    identifier: str
    source: str | None
    taper: str | None
    lineage: str | None
    download_count: int
    tracks: list[TrackResponse]


class ConcertResponse(BaseModel):
    id: str                # Phase 1 slug; opaque UUID after Phase 2 aggregation
    artist: str
    date: str
    venue: str | None
    location: str | None
    preferred_recording_id: str
    recordings: list[RecordingResponse]
