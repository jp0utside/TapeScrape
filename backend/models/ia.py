from pydantic import BaseModel, field_validator

_UNSUPPORTED_FORMATS = {"Ogg Vorbis", "Shorten"}


class IASearchItem(BaseModel):
    identifier: str
    title: str
    creator: str | None = None
    date: str | None = None
    downloads: int = 0


class IASearchResult(BaseModel):
    items: list[IASearchItem]
    total: int


class IAFile(BaseModel):
    name: str
    format: str
    title: str | None = None
    length: str | None = None
    size: str | None = None


class IAItemMetadata(BaseModel):
    identifier: str
    title: str
    creator: str | None = None
    date: str | None = None
    venue: str | None = None
    coverage: str | None = None
    source: str | None = None
    taper: str | None = None
    lineage: str | None = None
    description: str | None = None


class IAItem(BaseModel):
    metadata: IAItemMetadata
    files: list[IAFile]

    @field_validator("files", mode="before")
    @classmethod
    def drop_unsupported_formats(cls, files: list) -> list:
        return [f for f in files if f.get("format") not in _UNSUPPORTED_FORMATS]
