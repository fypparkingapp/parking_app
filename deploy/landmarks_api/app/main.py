from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware


@dataclass(frozen=True)
class LandmarkIndexEntry:
    record: dict[str, Any]
    search_blob: str


def _to_text(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def _to_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item).strip() for item in value if str(item).strip()]


def _safe_int(value: str | None, default: int) -> int:
    if value is None:
        return default
    try:
        return int(value)
    except ValueError:
        return default


class LandmarkStore:
    def __init__(self, data_dir: Path) -> None:
        self.data_dir = data_dir
        self.entries: list[LandmarkIndexEntry] = []
        self.file_counts: dict[str, int] = {}
        self.category_counts: dict[str, int] = {}
        self.subcategory_counts: dict[str, int] = {}
        self.total = 0
        self.reload()

    def reload(self) -> None:
        if not self.data_dir.exists():
            raise RuntimeError(f"Landmark directory does not exist: {self.data_dir}")

        entries: list[LandmarkIndexEntry] = []
        file_counts: dict[str, int] = {}
        category_counts: dict[str, int] = {}
        subcategory_counts: dict[str, int] = {}

        for file_path in sorted(self.data_dir.glob("*.json")):
            with file_path.open("r", encoding="utf-8") as handle:
                payload = json.load(handle)

            if not isinstance(payload, list):
                continue

            added = 0
            for item in payload:
                if not isinstance(item, dict):
                    continue

                category = _to_text(item.get("category"))
                subcategory = _to_text(item.get("subcategory"))
                display_name = _to_text(item.get("displayName"))
                name_zh = _to_text(item.get("nameZh"))
                name_en = _to_text(item.get("nameEn"))
                aliases_zh = _to_list(item.get("aliasesZh"))
                aliases_en = _to_list(item.get("aliasesEn"))

                normalized = {
                    "category": category,
                    "subcategory": subcategory,
                    "displayName": display_name,
                    "latitude": item.get("latitude"),
                    "longitude": item.get("longitude"),
                    "aliasesZh": aliases_zh,
                    "aliasesEn": aliases_en,
                    "nameZh": name_zh,
                    "nameEn": name_en,
                    "sourceFile": file_path.name,
                }
                search_blob = " ".join(
                    [
                        display_name,
                        name_zh,
                        name_en,
                        " ".join(aliases_zh),
                        " ".join(aliases_en),
                    ]
                ).casefold()

                entries.append(LandmarkIndexEntry(record=normalized, search_blob=search_blob))
                added += 1
                if category:
                    category_counts[category] = category_counts.get(category, 0) + 1
                if subcategory:
                    subcategory_counts[subcategory] = subcategory_counts.get(subcategory, 0) + 1

            file_counts[file_path.name] = added

        self.entries = entries
        self.file_counts = dict(sorted(file_counts.items()))
        self.category_counts = dict(sorted(category_counts.items()))
        self.subcategory_counts = dict(sorted(subcategory_counts.items()))
        self.total = len(entries)

    def search(
        self,
        q: str | None,
        category: str | None,
        subcategory: str | None,
        limit: int,
        offset: int,
    ) -> tuple[int, list[dict[str, Any]]]:
        needle = _to_text(q).casefold()
        category_filter = _to_text(category).casefold()
        subcategory_filter = _to_text(subcategory).casefold()

        matched: list[dict[str, Any]] = []
        for entry in self.entries:
            record = entry.record
            if category_filter and _to_text(record.get("category")).casefold() != category_filter:
                continue
            if subcategory_filter and _to_text(record.get("subcategory")).casefold() != subcategory_filter:
                continue
            if needle and needle not in entry.search_blob:
                continue
            matched.append(record)

        total = len(matched)
        return total, matched[offset : offset + limit]


def _resolve_data_dir() -> Path:
    module_dir = Path(__file__).resolve().parent
    repo_root = module_dir.parents[2]
    env_dir = os.getenv("LANDMARKS_DIR")
    candidates = []
    if env_dir:
        candidates.append(Path(env_dir))
    candidates.extend(
        [
            repo_root / "assets/data/local_landmarks",
            Path("assets/data/local_landmarks"),
            Path("/app/data/local_landmarks"),
        ]
    )
    for path in candidates:
        if path.exists():
            return path
    return candidates[0]


DATA_DIR = _resolve_data_dir()
DEFAULT_LIMIT = _safe_int(os.getenv("DEFAULT_LIMIT"), 50)
MAX_LIMIT = _safe_int(os.getenv("MAX_LIMIT"), 5000)
MAP_GOV_LOCATION_SEARCH_URL = os.getenv(
    "MAP_GOV_LOCATION_SEARCH_URL",
    "https://www.map.gov.hk/gs/api/v1.0.0/locationSearch",
)
MAP_GOV_REFERER = os.getenv("MAP_GOV_REFERER", "https://www.map.gov.hk/")
UPSTREAM_TIMEOUT_SECONDS = float(os.getenv("UPSTREAM_TIMEOUT_SECONDS", "10"))

store = LandmarkStore(DATA_DIR)

app = FastAPI(
    title="HK Local Landmarks API",
    version="1.0.0",
    description="Search API for local landmark records generated from LandsD location search data.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "ok": True,
        "total": store.total,
        "dataDir": str(store.data_dir),
    }


@app.get("/")
def root() -> dict[str, Any]:
    return {
        "service": "HK Local Landmarks API",
        "version": app.version,
        "docs": "/docs",
        "endpoints": [
            "/health",
            "/v1/meta",
            "/v1/categories",
            "/v1/landmarks",
            "/v1/landmarks/search",
            "/v1/landmarks/search/local",
            "/v1/admin/reload",
        ],
    }


@app.get("/v1/meta")
def meta() -> dict[str, Any]:
    return {
        "total": store.total,
        "files": store.file_counts,
        "categories": store.category_counts,
        "subcategories": store.subcategory_counts,
    }


@app.post("/v1/admin/reload")
def reload_data() -> dict[str, Any]:
    store.reload()
    return {"ok": True, "total": store.total}


@app.get("/v1/categories")
def categories() -> dict[str, Any]:
    return {
        "categories": store.category_counts,
        "subcategories": store.subcategory_counts,
        "total": store.total,
    }


def _sanitize_pagination(limit: int, offset: int) -> tuple[int, int]:
    if limit < 1:
        raise HTTPException(status_code=400, detail="limit must be >= 1")
    if offset < 0:
        raise HTTPException(status_code=400, detail="offset must be >= 0")
    if limit > MAX_LIMIT:
        limit = MAX_LIMIT
    return limit, offset


@app.get("/v1/landmarks")
def list_landmarks(
    category: str | None = Query(default=None),
    subcategory: str | None = Query(default=None),
    limit: int = Query(default=DEFAULT_LIMIT),
    offset: int = Query(default=0),
) -> dict[str, Any]:
    limit, offset = _sanitize_pagination(limit, offset)
    total, records = store.search(
        q=None,
        category=category,
        subcategory=subcategory,
        limit=limit,
        offset=offset,
    )
    return {
        "total": total,
        "limit": limit,
        "offset": offset,
        "items": records,
    }


@app.get("/v1/landmarks/search")
def search_landmarks(
    q: str = Query(min_length=1),
    limit: int = Query(default=DEFAULT_LIMIT),
    offset: int = Query(default=0),
) -> dict[str, Any]:
    limit, offset = _sanitize_pagination(limit, offset)
    items = _fetch_map_gov_location_search(q=q)
    total = len(items)
    return {
        "source": "map.gov.hk",
        "query": _to_text(q),
        "total": total,
        "limit": limit,
        "offset": offset,
        "items": items[offset : offset + limit],
    }


@app.get("/v1/landmarks/search/local")
def search_landmarks_local(
    q: str | None = Query(default=None),
    category: str | None = Query(default=None),
    subcategory: str | None = Query(default=None),
    limit: int = Query(default=DEFAULT_LIMIT),
    offset: int = Query(default=0),
) -> dict[str, Any]:
    limit, offset = _sanitize_pagination(limit, offset)
    total, records = store.search(
        q=q,
        category=category,
        subcategory=subcategory,
        limit=limit,
        offset=offset,
    )
    return {
        "query": _to_text(q),
        "total": total,
        "limit": limit,
        "offset": offset,
        "items": records,
    }


def _fetch_map_gov_location_search(q: str) -> list[dict[str, Any]]:
    url = MAP_GOV_LOCATION_SEARCH_URL + "?" + urlencode({"q": q})
    request = Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0",
            "Accept": "application/json",
            "Referer": MAP_GOV_REFERER,
        },
    )
    try:
        with urlopen(request, timeout=UPSTREAM_TIMEOUT_SECONDS) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        detail = f"map.gov.hk upstream HTTP {exc.code}"
        raise HTTPException(status_code=502, detail=detail) from exc
    except URLError as exc:
        detail = "map.gov.hk upstream connection failed"
        raise HTTPException(status_code=502, detail=detail) from exc
    except json.JSONDecodeError as exc:
        detail = "map.gov.hk upstream response is not valid JSON"
        raise HTTPException(status_code=502, detail=detail) from exc

    if not isinstance(payload, list):
        raise HTTPException(status_code=502, detail="map.gov.hk upstream payload is not a list")

    normalized: list[dict[str, Any]] = []
    for item in payload:
        if not isinstance(item, dict):
            continue
        normalized.append(
            {
                "nameZh": _to_text(item.get("nameZH")),
                "nameEn": _to_text(item.get("nameEN")),
                "addressZh": _to_text(item.get("addressZH")),
                "addressEn": _to_text(item.get("addressEN")),
                "districtZh": _to_text(item.get("districtZH")),
                "districtEn": _to_text(item.get("districtEN")),
                "x": item.get("x"),
                "y": item.get("y"),
                "raw": item,
            }
        )
    return normalized
