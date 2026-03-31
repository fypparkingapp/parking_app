#!/usr/bin/env python3
"""Capture candidate landmarks from LandsD GeoInfo Map location search.

Single query examples:
  python3 scripts/landsd_location_capture.py "Festival Walk" \
    --subcategory mall \
    --exact-name "Festival Walk"

  python3 scripts/landsd_location_capture.py "太古" \
    --subcategory officeTower \
    --name-contains "One Island East" \
    --append-to assets/data/local_landmarks/office_towers.json

Batch import example:
  python3 scripts/landsd_location_capture.py \
    --batch-file scripts/landsd_batch_template.csv \
    --batch-sleep-ms 250
"""

from __future__ import annotations

import argparse
import concurrent.futures
import csv
import json
import math
import sys
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


API_BASE = "https://www.map.gov.hk/gs/api/v1.0.0/locationSearch"
REQUEST_HEADERS = {
    "User-Agent": "Mozilla/5.0",
    "Accept": "application/json, text/plain, */*",
    "Referer": "https://www.map.gov.hk/gm/",
    "Origin": "https://www.map.gov.hk",
    "Accept-Language": "en-US,en;q=0.9,zh-HK;q=0.8,zh;q=0.7",
}

# HK1980 grid / datum parameters from GeoInfo Map's bundled Proj4js config.
HK80_A = 6378388.0
HK80_RF = 297.0
HK80_LAT0 = math.radians(22.31213333333334)
HK80_LON0 = math.radians(114.1785555555556)
HK80_K0 = 1.0
HK80_FALSE_EASTING = 836694.05
HK80_FALSE_NORTHING = 819069.8
HK80_DX = -162.619
HK80_DY = -276.959
HK80_DZ = -161.764
HK80_RX = math.radians(0.067753 / 3600.0)
HK80_RY = math.radians(-2.24365 / 3600.0)
HK80_RZ = math.radians(-1.15883 / 3600.0)
HK80_SCALE = -1.09425e-6

WGS84_A = 6378137.0
WGS84_RF = 298.257223563

SUBCATEGORY_TO_CATEGORY = {
    "campus": "education",
    "school": "education",
    "mall": "shoppingRetail",
    "majorDestination": "cultureLeisure",
    "officeTower": "businessOffice",
    "industrialArea": "businessOffice",
    "housingEstate": "residentialHousing",
    "hospital": "medicalHealth",
    "governmentOffice": "governmentPublic",
    "hotel": "cultureLeisure",
    "themePark": "cultureLeisure",
    "artsVenue": "cultureLeisure",
}

DEFAULT_OUTPUT_BY_SUBCATEGORY = {
    "campus": "assets/data/local_landmarks/campuses.json",
    "school": "assets/data/local_landmarks/schools.json",
    "mall": "assets/data/local_landmarks/malls.json",
    "majorDestination": "assets/data/local_landmarks/major_destinations.json",
    "officeTower": "assets/data/local_landmarks/office_towers.json",
    "industrialArea": "assets/data/local_landmarks/industrial_areas.json",
    "housingEstate": "assets/data/local_landmarks/housing_estates.json",
    "hospital": "assets/data/local_landmarks/hospitals.json",
    "governmentOffice": "assets/data/local_landmarks/government_offices.json",
    "hotel": "assets/data/local_landmarks/hotels.json",
    "themePark": "assets/data/local_landmarks/theme_parks.json",
    "artsVenue": "assets/data/local_landmarks/arts_venues.json",
}


@dataclass(frozen=True)
class CaptureSpec:
    query: str
    subcategory: str
    limit: int
    district: str
    exact_name: str
    name_contains: str
    aliases_en: set[str]
    aliases_zh: set[str]
    append_to: str
    enabled: bool = True
    label: str = ""


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        if args.batch_file:
            return run_batch(args)
        return run_single(args)
    except Exception as exc:  # pragma: no cover - top-level CLI guard
        print(f"Error: {exc}", file=sys.stderr)
        return 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Capture new landmark candidates from LandsD Location Search API.",
    )
    parser.add_argument(
        "query",
        nargs="?",
        help="Search keyword sent to map.gov.hk for single-query mode.",
    )
    parser.add_argument(
        "--batch-file",
        help="CSV file for batch import mode.",
    )
    parser.add_argument(
        "--subcategory",
        choices=sorted(SUBCATEGORY_TO_CATEGORY.keys()),
        help="Landmark subcategory used in single-query mode.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=20,
        help="Maximum number of filtered hits to emit per query.",
    )
    parser.add_argument(
        "--district",
        default="",
        help="Keep only results whose Chinese or English district contains this text.",
    )
    parser.add_argument(
        "--exact-name",
        default="",
        help="Keep only results whose Chinese or English name exactly matches this text.",
    )
    parser.add_argument(
        "--name-contains",
        default="",
        help="Keep only results whose Chinese or English name contains this text.",
    )
    parser.add_argument(
        "--append-to",
        default="",
        help="Append merged output into an existing landmark JSON file.",
    )
    parser.add_argument(
        "--aliases-en",
        default="",
        help="Comma-separated aliases to add to aliasesEn.",
    )
    parser.add_argument(
        "--aliases-zh",
        default="",
        help="Comma-separated aliases to add to aliasesZh.",
    )
    parser.add_argument(
        "--dedupe-radius",
        type=float,
        default=35.0,
        help="Merge entries with same names inside this many meters.",
    )
    parser.add_argument(
        "--batch-sleep-ms",
        type=int,
        default=250,
        help="Pause between batch requests in milliseconds.",
    )
    parser.add_argument(
        "--batch-limit",
        type=int,
        default=0,
        help="Only process the first N enabled rows from the CSV file.",
    )
    parser.add_argument(
        "--stop-on-error",
        action="store_true",
        help="Abort the batch on the first failing row.",
    )
    parser.add_argument(
        "--summary-json",
        default="",
        help="Optional path to save the batch summary JSON.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print request and merge details to stderr.",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=1,
        help="Number of parallel workers in batch mode.",
    )
    return parser


def run_single(args: argparse.Namespace) -> int:
    if not args.query:
        raise RuntimeError("Single-query mode requires a query.")
    if not args.subcategory:
        raise RuntimeError("Single-query mode requires --subcategory.")

    spec = CaptureSpec(
        query=args.query,
        subcategory=args.subcategory,
        limit=args.limit,
        district=args.district,
        exact_name=args.exact_name,
        name_contains=args.name_contains,
        aliases_en=parse_alias_list(args.aliases_en),
        aliases_zh=parse_alias_list(args.aliases_zh),
        append_to=args.append_to,
        label=args.query,
    )

    result = capture_from_spec(
        spec,
        dedupe_radius=args.dedupe_radius,
        verbose=args.verbose,
    )
    candidates = result["candidates"]

    if spec.append_to:
        merged = merge_into_file(
            Path(spec.append_to),
            candidates,
            radius_meters=args.dedupe_radius,
            verbose=args.verbose,
        )
        print(
            f"Saved {len(candidates)} new candidate(s); "
            f"{len(merged)} total landmark(s) in {spec.append_to}",
            file=sys.stderr,
        )
    else:
        json.dump(candidates, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")

    if args.verbose:
        print(
            f"Fetched {result['fetched']} hit(s), kept {result['filtered']} after filters, "
            f"emitted {len(candidates)} landmark(s).",
            file=sys.stderr,
        )
    return 0


def run_batch(args: argparse.Namespace) -> int:
    specs = load_batch_specs(Path(args.batch_file))
    enabled_specs = [spec for spec in specs if spec.enabled]
    if args.batch_limit > 0:
        enabled_specs = enabled_specs[: args.batch_limit]
    if not enabled_specs:
        raise RuntimeError("No enabled rows found in batch file.")

    pending_writes: dict[Path, list[dict]] = {}
    summary: list[dict] = []
    workers = max(1, int(args.workers))

    if workers == 1:
        for index, spec in enumerate(enabled_specs, start=1):
            try:
                result = capture_from_spec(
                    spec,
                    dedupe_radius=args.dedupe_radius,
                    verbose=args.verbose,
                )
                target_path = resolve_output_path(spec)
                if target_path is not None:
                    pending_writes.setdefault(target_path, []).extend(result["candidates"])
                summary.append(
                    {
                        "index": index,
                        "query": spec.query,
                        "label": spec.label or spec.query,
                        "subcategory": spec.subcategory,
                        "appendTo": str(target_path) if target_path else "",
                        "fetched": result["fetched"],
                        "filtered": result["filtered"],
                        "emitted": len(result["candidates"]),
                        "status": "ok",
                    }
                )
                print(
                    f"[{index}/{len(enabled_specs)}] {spec.label or spec.query}: "
                    f"{len(result['candidates'])} candidate(s)",
                    file=sys.stderr,
                )
            except Exception as exc:
                summary.append(
                    {
                        "index": index,
                        "query": spec.query,
                        "label": spec.label or spec.query,
                        "subcategory": spec.subcategory,
                        "appendTo": spec.append_to,
                        "status": "error",
                        "error": str(exc),
                    }
                )
                print(
                    f"[{index}/{len(enabled_specs)}] {spec.label or spec.query}: {exc}",
                    file=sys.stderr,
                )
                if args.stop_on_error:
                    raise
            if index != len(enabled_specs) and args.batch_sleep_ms > 0:
                time.sleep(args.batch_sleep_ms / 1000.0)
    else:
        print(
            f"Running batch with {workers} parallel worker(s).",
            file=sys.stderr,
        )
        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
            future_map = {
                executor.submit(
                    capture_from_spec,
                    spec,
                    dedupe_radius=args.dedupe_radius,
                    verbose=args.verbose,
                ): (index, spec)
                for index, spec in enumerate(enabled_specs, start=1)
            }

            for future in concurrent.futures.as_completed(future_map):
                index, spec = future_map[future]
                try:
                    result = future.result()
                    target_path = resolve_output_path(spec)
                    if target_path is not None:
                        pending_writes.setdefault(target_path, []).extend(
                            result["candidates"]
                        )
                    summary.append(
                        {
                            "index": index,
                            "query": spec.query,
                            "label": spec.label or spec.query,
                            "subcategory": spec.subcategory,
                            "appendTo": str(target_path) if target_path else "",
                            "fetched": result["fetched"],
                            "filtered": result["filtered"],
                            "emitted": len(result["candidates"]),
                            "status": "ok",
                        }
                    )
                    print(
                        f"[{index}/{len(enabled_specs)}] {spec.label or spec.query}: "
                        f"{len(result['candidates'])} candidate(s)",
                        file=sys.stderr,
                    )
                except Exception as exc:
                    summary.append(
                        {
                            "index": index,
                            "query": spec.query,
                            "label": spec.label or spec.query,
                            "subcategory": spec.subcategory,
                            "appendTo": spec.append_to,
                            "status": "error",
                            "error": str(exc),
                        }
                    )
                    print(
                        f"[{index}/{len(enabled_specs)}] {spec.label or spec.query}: {exc}",
                        file=sys.stderr,
                    )
                    if args.stop_on_error:
                        raise

    summary.sort(key=lambda item: item["index"])

    written_files: list[dict] = []
    for path, items in sorted(pending_writes.items(), key=lambda item: str(item[0])):
        merged = merge_into_file(
            path,
            items,
            radius_meters=args.dedupe_radius,
            verbose=args.verbose,
        )
        written_files.append(
            {
                "path": str(path),
                "newCandidates": len(items),
                "totalItems": len(merged),
            }
        )

    report = {
        "processed": len(enabled_specs),
        "succeeded": sum(1 for item in summary if item["status"] == "ok"),
        "failed": sum(1 for item in summary if item["status"] == "error"),
        "writtenFiles": written_files,
        "rows": summary,
    }

    if args.summary_json:
        summary_path = Path(args.summary_json)
        summary_path.parent.mkdir(parents=True, exist_ok=True)
        summary_path.write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"Saved summary to {summary_path}", file=sys.stderr)

    json.dump(report, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


def load_batch_specs(path: Path) -> list[CaptureSpec]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        required = {"query", "subcategory"}
        missing = required - set(reader.fieldnames or [])
        if missing:
            raise RuntimeError(
                f"Batch CSV is missing required column(s): {', '.join(sorted(missing))}"
            )

        specs: list[CaptureSpec] = []
        for row_number, row in enumerate(reader, start=2):
            if row is None:
                continue
            query = clean_text(row.get("query"))
            if not query:
                continue
            subcategory = clean_text(row.get("subcategory"))
            if subcategory not in SUBCATEGORY_TO_CATEGORY:
                raise RuntimeError(
                    f"Row {row_number}: unknown subcategory '{subcategory}'."
                )
            limit = parse_int_or_default(row.get("limit"), 20)
            enabled = parse_bool(row.get("enabled"), default=True)
            append_to = clean_text(row.get("append_to"))
            if not append_to:
                append_to = DEFAULT_OUTPUT_BY_SUBCATEGORY[subcategory]

            specs.append(
                CaptureSpec(
                    query=query,
                    subcategory=subcategory,
                    limit=limit,
                    district=clean_text(row.get("district")),
                    exact_name=clean_text(row.get("exact_name")),
                    name_contains=clean_text(row.get("name_contains")),
                    aliases_en=parse_alias_list(row.get("aliases_en", "")),
                    aliases_zh=parse_alias_list(row.get("aliases_zh", "")),
                    append_to=append_to,
                    enabled=enabled,
                    label=clean_text(row.get("label")) or query,
                )
            )
    return specs


def capture_from_spec(
    spec: CaptureSpec,
    *,
    dedupe_radius: float,
    verbose: bool,
) -> dict:
    hits = fetch_locations(spec.query, verbose=verbose)
    filtered = filter_hits(
        hits,
        district=spec.district,
        exact_name=spec.exact_name,
        name_contains=spec.name_contains,
    )
    candidates = [
        build_landmark(
            hit,
            spec.subcategory,
            extra_aliases_en=spec.aliases_en,
            extra_aliases_zh=spec.aliases_zh,
        )
        for hit in filtered[: spec.limit]
    ]
    candidates = dedupe_landmarks(candidates, radius_meters=dedupe_radius)
    return {
        "fetched": len(hits),
        "filtered": len(filtered),
        "candidates": candidates,
    }


def resolve_output_path(spec: CaptureSpec) -> Path | None:
    target = clean_text(spec.append_to)
    if not target:
        return None
    return Path(target)


def fetch_locations(query: str, *, verbose: bool = False) -> list[dict]:
    params = urllib.parse.urlencode({"q": query})
    url = f"{API_BASE}?{params}"
    if verbose:
        print(f"[GET] {url}", file=sys.stderr)
    request = urllib.request.Request(url, headers=REQUEST_HEADERS)
    with urllib.request.urlopen(request, timeout=20) as response:
        payload = response.read().decode("utf-8")
    data = json.loads(payload)
    if not isinstance(data, list):
        raise RuntimeError("Unexpected API response: expected a JSON list.")
    return [item for item in data if isinstance(item, dict)]


def filter_hits(
    hits: Iterable[dict],
    *,
    district: str,
    exact_name: str,
    name_contains: str,
) -> list[dict]:
    district_filter = normalize_text(district)
    exact_name_filter = normalize_text(exact_name)
    contains_filter = normalize_text(name_contains)

    out: list[dict] = []
    for hit in hits:
        names = [
            hit.get("nameEN", ""),
            hit.get("nameZH", ""),
        ]
        districts = [
            hit.get("districtEN", ""),
            hit.get("districtZH", ""),
        ]
        normalized_names = [normalize_text(value) for value in names]
        normalized_districts = [normalize_text(value) for value in districts]

        if district_filter and not any(
            district_filter in district_name
            for district_name in normalized_districts
        ):
            continue
        if exact_name_filter and exact_name_filter not in normalized_names:
            continue
        if contains_filter and not any(
            contains_filter in name for name in normalized_names
        ):
            continue
        out.append(hit)
    return out


def build_landmark(
    hit: dict,
    subcategory: str,
    *,
    extra_aliases_en: set[str],
    extra_aliases_zh: set[str],
) -> dict:
    latitude, longitude = hk1980_to_wgs84(
        float(hit["x"]),
        float(hit["y"]),
    )
    aliases_en = set(extra_aliases_en)
    aliases_zh = set(extra_aliases_zh)

    display_name = clean_text(hit.get("nameEN")) or clean_text(hit.get("nameZH"))
    if not display_name:
        raise RuntimeError(f"Missing name in hit: {hit}")

    landmark = {
        "category": SUBCATEGORY_TO_CATEGORY[subcategory],
        "subcategory": subcategory,
        "displayName": display_name,
        "latitude": round(latitude, 6),
        "longitude": round(longitude, 6),
        "aliasesZh": [],
        "aliasesEn": [],
    }

    name_zh = clean_text(hit.get("nameZH"))
    name_en = clean_text(hit.get("nameEN"))
    address_zh = clean_text(hit.get("addressZH"))
    address_en = clean_text(hit.get("addressEN"))

    if name_zh:
        landmark["nameZh"] = name_zh
    if name_en:
        landmark["nameEn"] = name_en

    if address_zh:
        aliases_zh.add(address_zh)
    if address_en:
        aliases_en.add(address_en)

    landmark["aliasesZh"] = sorted(
        alias for alias in aliases_zh if alias and alias != name_zh
    )
    landmark["aliasesEn"] = sorted(
        alias
        for alias in aliases_en
        if alias and normalize_text(alias) != normalize_text(name_en)
    )
    return landmark


def merge_into_file(
    path: Path,
    new_items: list[dict],
    *,
    radius_meters: float,
    verbose: bool = False,
) -> list[dict]:
    existing: list[dict] = []
    if path.exists():
        existing = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(existing, list):
            raise RuntimeError(f"{path} does not contain a JSON list.")
    merged = dedupe_landmarks(existing + new_items, radius_meters=radius_meters)
    merged.sort(key=lambda item: normalize_text(item.get("displayName", "")))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(merged, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if verbose:
        print(f"[write] {path} ({len(merged)} item(s))", file=sys.stderr)
    return merged


def dedupe_landmarks(items: list[dict], *, radius_meters: float) -> list[dict]:
    unique: list[dict] = []
    for item in items:
        matched_index = None
        for index, existing in enumerate(unique):
            if is_same_landmark(existing, item, radius_meters=radius_meters):
                matched_index = index
                break
        if matched_index is None:
            unique.append(item)
            continue
        unique[matched_index] = merge_landmark(
            existing=unique[matched_index],
            incoming=item,
        )
    return unique


def is_same_landmark(existing: dict, incoming: dict, *, radius_meters: float) -> bool:
    existing_names = {
        normalize_text(existing.get("displayName", "")),
        normalize_text(existing.get("nameEn", "")),
        normalize_text(existing.get("nameZh", "")),
    }
    incoming_names = {
        normalize_text(incoming.get("displayName", "")),
        normalize_text(incoming.get("nameEn", "")),
        normalize_text(incoming.get("nameZh", "")),
    }
    existing_names.discard("")
    incoming_names.discard("")
    if not existing_names or not incoming_names:
        return False
    if existing_names.isdisjoint(incoming_names):
        return False

    distance = haversine_meters(
        float(existing["latitude"]),
        float(existing["longitude"]),
        float(incoming["latitude"]),
        float(incoming["longitude"]),
    )
    return distance <= radius_meters


def merge_landmark(*, existing: dict, incoming: dict) -> dict:
    merged = dict(existing)
    for key in ("nameZh", "nameEn"):
        if not merged.get(key) and incoming.get(key):
            merged[key] = incoming[key]
    for key in ("aliasesZh", "aliasesEn"):
        merged[key] = sorted(
            {
                *merged.get(key, []),
                *incoming.get(key, []),
            },
            key=lambda value: normalize_text(value),
        )
    return merged


def parse_alias_list(raw: str) -> set[str]:
    text = clean_text(raw)
    if not text:
        return set()
    return {
        clean_text(item)
        for item in text.split(",")
        if clean_text(item)
    }


def parse_int_or_default(raw: object, default: int) -> int:
    text = clean_text(raw)
    if not text:
        return default
    return int(text)


def parse_bool(raw: object, *, default: bool) -> bool:
    text = normalize_text(raw)
    if not text:
        return default
    if text in {"1", "true", "yes", "y", "on"}:
        return True
    if text in {"0", "false", "no", "n", "off"}:
        return False
    raise RuntimeError(f"Invalid boolean value: {raw}")


def clean_text(value: object) -> str:
    if value is None:
        return ""
    return " ".join(str(value).split()).strip()


def normalize_text(value: object) -> str:
    return clean_text(value).casefold()


def haversine_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    radius = 6371000.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = (
        math.sin(dphi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    )
    return 2 * radius * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def hk1980_to_wgs84(easting: float, northing: float) -> tuple[float, float]:
    hk80_lat, hk80_lon = inverse_hk1980_tmerc(easting, northing)
    x, y, z = geodetic_to_ecef(hk80_lat, hk80_lon, HK80_A, HK80_RF)
    x, y, z = helmert_to_wgs84(x, y, z)
    lat, lon, _ = ecef_to_geodetic(x, y, z, WGS84_A, WGS84_RF)
    return math.degrees(lat), math.degrees(lon)


def inverse_hk1980_tmerc(easting: float, northing: float) -> tuple[float, float]:
    b = HK80_A * (1.0 - 1.0 / HK80_RF)
    e2 = (HK80_A * HK80_A - b * b) / (HK80_A * HK80_A)
    ep2 = e2 / (1.0 - e2)

    x = (easting - HK80_FALSE_EASTING) / HK80_K0
    y = (northing - HK80_FALSE_NORTHING) / HK80_K0
    meridional = meridional_arc(HK80_LAT0, HK80_A, e2) + y
    mu = meridional / (
        HK80_A * (1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2**3 / 256)
    )

    e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2))
    phi1 = (
        mu
        + (3 * e1 / 2 - 27 * e1**3 / 32) * math.sin(2 * mu)
        + (21 * e1 * e1 / 16 - 55 * e1**4 / 32) * math.sin(4 * mu)
        + (151 * e1**3 / 96) * math.sin(6 * mu)
        + (1097 * e1**4 / 512) * math.sin(8 * mu)
    )

    n1 = HK80_A / math.sqrt(1 - e2 * math.sin(phi1) ** 2)
    t1 = math.tan(phi1) ** 2
    c1 = ep2 * math.cos(phi1) ** 2
    r1 = HK80_A * (1 - e2) / (1 - e2 * math.sin(phi1) ** 2) ** 1.5
    d = x / n1

    latitude = phi1 - (n1 * math.tan(phi1) / r1) * (
        d**2 / 2
        - (5 + 3 * t1 + 10 * c1 - 4 * c1**2 - 9 * ep2) * d**4 / 24
        + (61 + 90 * t1 + 298 * c1 + 45 * t1**2 - 252 * ep2 - 3 * c1**2)
        * d**6
        / 720
    )
    longitude = HK80_LON0 + (
        d
        - (1 + 2 * t1 + c1) * d**3 / 6
        + (5 - 2 * c1 + 28 * t1 - 3 * c1**2 + 8 * ep2 + 24 * t1**2)
        * d**5
        / 120
    ) / math.cos(phi1)
    return latitude, longitude


def meridional_arc(
    latitude: float,
    semi_major_axis: float,
    eccentricity_sq: float,
) -> float:
    return semi_major_axis * (
        (
            1
            - eccentricity_sq / 4
            - 3 * eccentricity_sq**2 / 64
            - 5 * eccentricity_sq**3 / 256
        )
        * latitude
        - (
            3 * eccentricity_sq / 8
            + 3 * eccentricity_sq**2 / 32
            + 45 * eccentricity_sq**3 / 1024
        )
        * math.sin(2 * latitude)
        + (15 * eccentricity_sq**2 / 256 + 45 * eccentricity_sq**3 / 1024)
        * math.sin(4 * latitude)
        - (35 * eccentricity_sq**3 / 3072) * math.sin(6 * latitude)
    )


def geodetic_to_ecef(
    latitude: float,
    longitude: float,
    semi_major_axis: float,
    reciprocal_flattening: float,
) -> tuple[float, float, float]:
    semi_minor_axis = semi_major_axis * (1.0 - 1.0 / reciprocal_flattening)
    eccentricity_sq = (
        semi_major_axis * semi_major_axis - semi_minor_axis * semi_minor_axis
    ) / (semi_major_axis * semi_major_axis)
    nu = semi_major_axis / math.sqrt(1 - eccentricity_sq * math.sin(latitude) ** 2)
    x = nu * math.cos(latitude) * math.cos(longitude)
    y = nu * math.cos(latitude) * math.sin(longitude)
    z = (nu * (1 - eccentricity_sq)) * math.sin(latitude)
    return x, y, z


def helmert_to_wgs84(x: float, y: float, z: float) -> tuple[float, float, float]:
    transformed_x = HK80_DX + (1 + HK80_SCALE) * x - HK80_RZ * y + HK80_RY * z
    transformed_y = HK80_DY + HK80_RZ * x + (1 + HK80_SCALE) * y - HK80_RX * z
    transformed_z = HK80_DZ - HK80_RY * x + HK80_RX * y + (1 + HK80_SCALE) * z
    return transformed_x, transformed_y, transformed_z


def ecef_to_geodetic(
    x: float,
    y: float,
    z: float,
    semi_major_axis: float,
    reciprocal_flattening: float,
) -> tuple[float, float, float]:
    flattening = 1.0 / reciprocal_flattening
    semi_minor_axis = semi_major_axis * (1.0 - flattening)
    eccentricity_sq = (
        semi_major_axis * semi_major_axis - semi_minor_axis * semi_minor_axis
    ) / (semi_major_axis * semi_major_axis)
    second_eccentricity_sq = (
        semi_major_axis * semi_major_axis - semi_minor_axis * semi_minor_axis
    ) / (semi_minor_axis * semi_minor_axis)

    p = math.hypot(x, y)
    theta = math.atan2(semi_major_axis * z, semi_minor_axis * p)
    longitude = math.atan2(y, x)
    latitude = math.atan2(
        z + second_eccentricity_sq * semi_minor_axis * math.sin(theta) ** 3,
        p - eccentricity_sq * semi_major_axis * math.cos(theta) ** 3,
    )

    for _ in range(5):
        nu = semi_major_axis / math.sqrt(1 - eccentricity_sq * math.sin(latitude) ** 2)
        height = p / math.cos(latitude) - nu
        latitude = math.atan2(
            z,
            p * (1 - eccentricity_sq * nu / (nu + height)),
        )

    nu = semi_major_axis / math.sqrt(1 - eccentricity_sq * math.sin(latitude) ** 2)
    height = p / math.cos(latitude) - nu
    return latitude, longitude, height


if __name__ == "__main__":
    raise SystemExit(main())
