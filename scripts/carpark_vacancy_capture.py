#!/usr/bin/env python3
"""Capture Hong Kong carpark vacancy snapshots for backend history storage.

This script is designed for cron / scheduler use in a backend environment.
It fetches the current carpark feeds used by the app, stores raw snapshots,
emits a normalized JSONL snapshot, and appends normalized rows into a history
JSONL file suitable for downstream training jobs.

Example:
  python3 scripts/carpark_vacancy_capture.py \
    --output-dir ./data/carpark_capture

Example cron (every 10 minutes):
  */10 * * * * /usr/bin/python3 /srv/backend/scripts/carpark_vacancy_capture.py \
    --output-dir /srv/backend/data/carpark_capture >> /srv/backend/logs/carpark_capture.log 2>&1
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import sys
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


GOV_INFO_URL = "https://api.data.gov.hk/v1/carpark-info-vacancy"
GOV_VACANCY_URL = "https://resource.data.one.gov.hk/td/carpark/vacancy_all.json"
RYAN_METADATA_URL = "https://parkapi2.ryanpumpkin.com/carparks"
METER_SPACEINFO_URL = (
    "https://resource.data.one.gov.hk/td/psiparkingspaces/spaceinfo/parkingspaces.csv"
)
METER_OCCUPANCY_URL = (
    "https://resource.data.one.gov.hk/td/psiparkingspaces/occupancystatus/occupancystatus.csv"
)

REQUEST_HEADERS = {
    "User-Agent": "wilson-parking-capture/1.0",
    "Accept": "application/json, text/plain, */*",
}


@dataclass(frozen=True)
class SourcePayload:
    name: str
    url: str
    fetched_at: str
    status_code: int
    body: str
    data: Any
    raw_format: str


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        return run_capture(args)
    except Exception as exc:  # pragma: no cover - CLI guard
        print(f"Error: {exc}", file=sys.stderr)
        return 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Capture raw and normalized carpark vacancy history snapshots.",
    )
    parser.add_argument(
        "--output-dir",
        default="tmp/carpark_vacancy_capture",
        help="Root directory for latest, archive, and history outputs.",
    )
    parser.add_argument(
        "--history-file",
        default="",
        help=(
            "Optional JSONL path for appended history rows. "
            "Defaults to <output-dir>/history/carpark_vacancy_history.jsonl."
        ),
    )
    parser.add_argument(
        "--timeout-sec",
        type=float,
        default=30.0,
        help="Network timeout in seconds for each source fetch.",
    )
    parser.add_argument(
        "--snapshot-id",
        default="",
        help="Optional snapshot id override. Defaults to UTC timestamp.",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Fail if any source fetch fails, including optional metadata.",
    )
    parser.add_argument(
        "--skip-raw",
        action="store_true",
        help="Do not save raw source payloads to disk.",
    )
    parser.add_argument(
        "--skip-archive",
        action="store_true",
        help="Do not write dated archive files; only latest/ and history/ outputs.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print fetch and output details to stderr.",
    )
    parser.add_argument(
        "--skip-meter",
        action="store_true",
        help="Skip metered parking space capture outputs.",
    )
    return parser


def run_capture(args: argparse.Namespace) -> int:
    observed_at = dt.datetime.now(dt.timezone.utc)
    snapshot_id = args.snapshot_id or observed_at.strftime("%Y%m%dT%H%M%SZ")
    observed_at_iso = observed_at.isoformat().replace("+00:00", "Z")

    output_dir = Path(args.output_dir)
    latest_dir = output_dir / "latest"
    latest_raw_dir = latest_dir / "raw"
    archive_dir = output_dir / "archive" / observed_at.strftime("%Y%m%d")
    history_dir = output_dir / "history"
    history_file = (
        Path(args.history_file)
        if args.history_file
        else history_dir / "carpark_vacancy_history.jsonl"
    )
    metered_history_file = history_dir / "metered_space_history.jsonl"

    latest_dir.mkdir(parents=True, exist_ok=True)
    history_dir.mkdir(parents=True, exist_ok=True)
    if not args.skip_raw:
        latest_raw_dir.mkdir(parents=True, exist_ok=True)
    if not args.skip_archive:
        archive_dir.mkdir(parents=True, exist_ok=True)

    source_specs = [
        ("gov_info", GOV_INFO_URL, True, "json"),
        ("gov_vacancy", GOV_VACANCY_URL, True, "json"),
        ("ryan_metadata", RYAN_METADATA_URL, False, "json"),
    ]
    if not args.skip_meter:
        source_specs.extend(
            [
                ("meter_spaceinfo", METER_SPACEINFO_URL, True, "csv"),
                ("meter_occupancy", METER_OCCUPANCY_URL, True, "csv"),
            ]
        )

    sources: dict[str, SourcePayload] = {}
    errors: list[dict[str, str]] = []
    for name, url, required, raw_format in source_specs:
        try:
            payload = (
                fetch_json_source(name, url, timeout_sec=args.timeout_sec)
                if raw_format == "json"
                else fetch_text_source(name, url, timeout_sec=args.timeout_sec)
            )
            sources[name] = payload
            if args.verbose:
                print(
                    f"[fetch] {name}: {payload.status_code} {len(payload.body)} bytes",
                    file=sys.stderr,
                )
        except Exception as exc:
            errors.append({"source": name, "error": str(exc)})
            if required or args.strict:
                raise
            print(f"[warn] {name}: {exc}", file=sys.stderr)

    gov_info_rows = parse_gov_info_rows(sources["gov_info"].data)
    gov_vacancy_map = parse_gov_vacancy_map(sources["gov_vacancy"].data)
    ryan_map = parse_ryan_metadata_map(sources.get("ryan_metadata"))
    normalized_rows = build_normalized_rows(
        observed_at_iso=observed_at_iso,
        snapshot_id=snapshot_id,
        gov_info_rows=gov_info_rows,
        gov_vacancy_map=gov_vacancy_map,
        ryan_map=ryan_map,
    )
    metered_rows = (
        build_metered_rows(
            observed_at_iso=observed_at_iso,
            snapshot_id=snapshot_id,
            meter_space_csv=sources["meter_spaceinfo"].body,
            meter_occupancy_csv=sources["meter_occupancy"].body,
        )
        if not args.skip_meter
        else []
    )

    latest_normalized_path = latest_dir / "normalized.jsonl"
    write_jsonl(latest_normalized_path, normalized_rows)
    append_jsonl(history_file, normalized_rows)
    latest_metered_normalized_path: Path | None = None
    if metered_rows:
        latest_metered_normalized_path = latest_dir / "metered_normalized.jsonl"
        write_jsonl(latest_metered_normalized_path, metered_rows)
        append_jsonl(metered_history_file, metered_rows)

    archive_normalized_path: Path | None = None
    archive_metered_normalized_path: Path | None = None
    if not args.skip_archive:
        archive_normalized_path = archive_dir / f"{snapshot_id}__normalized.jsonl"
        write_jsonl(archive_normalized_path, normalized_rows)
        if metered_rows:
            archive_metered_normalized_path = (
                archive_dir / f"{snapshot_id}__metered_normalized.jsonl"
            )
            write_jsonl(archive_metered_normalized_path, metered_rows)

    raw_paths: dict[str, str] = {}
    if not args.skip_raw:
        for name, payload in sources.items():
            suffix = ".json" if payload.raw_format == "json" else ".csv"
            latest_raw_path = latest_raw_dir / f"{name}{suffix}"
            latest_raw_path.write_text(payload.body, encoding="utf-8")
            raw_paths[f"latest_{name}"] = str(latest_raw_path)
            if not args.skip_archive:
                archive_raw_path = archive_dir / f"{snapshot_id}__{name}{suffix}"
                archive_raw_path.write_text(payload.body, encoding="utf-8")
                raw_paths[f"archive_{name}"] = str(archive_raw_path)

    manifest = build_manifest(
        observed_at_iso=observed_at_iso,
        snapshot_id=snapshot_id,
        normalized_rows=normalized_rows,
        metered_rows=metered_rows,
        latest_normalized_path=latest_normalized_path,
        latest_metered_normalized_path=latest_metered_normalized_path,
        archive_normalized_path=archive_normalized_path,
        archive_metered_normalized_path=archive_metered_normalized_path,
        history_file=history_file,
        metered_history_file=metered_history_file if metered_rows else None,
        sources=sources,
        raw_paths=raw_paths,
        errors=errors,
    )
    latest_manifest_path = latest_dir / "manifest.json"
    latest_manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if not args.skip_archive:
        archive_manifest_path = archive_dir / f"{snapshot_id}__manifest.json"
        archive_manifest_path.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    print(
        json.dumps(
            {
                "snapshot_id": snapshot_id,
                "observed_at": observed_at_iso,
                "normalized_rows": len(normalized_rows),
                "metered_rows": len(metered_rows),
                "history_file": str(history_file),
                "latest_manifest": str(latest_manifest_path),
            },
            ensure_ascii=False,
        )
    )
    return 0


def fetch_json_source(name: str, url: str, timeout_sec: float) -> SourcePayload:
    fetched_at = dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")
    req = urllib.request.Request(url, headers=REQUEST_HEADERS)
    with urllib.request.urlopen(req, timeout=timeout_sec) as response:
        body = response.read().decode("utf-8-sig").strip()
        if body.startswith("?"):
            body = body[1:].lstrip()
        data = json.loads(body)
        return SourcePayload(
            name=name,
            url=url,
            fetched_at=fetched_at,
            status_code=response.status,
            body=body,
            data=data,
            raw_format="json",
        )


def fetch_text_source(name: str, url: str, timeout_sec: float) -> SourcePayload:
    fetched_at = dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")
    req = urllib.request.Request(url, headers=REQUEST_HEADERS)
    with urllib.request.urlopen(req, timeout=timeout_sec) as response:
        body = response.read().decode("utf-8-sig")
        return SourcePayload(
            name=name,
            url=url,
            fetched_at=fetched_at,
            status_code=response.status,
            body=body,
            data=None,
            raw_format="csv",
        )


def parse_gov_info_rows(payload: Any) -> dict[str, dict[str, Any]]:
    rows = payload.get("results") if isinstance(payload, dict) else None
    if not isinstance(rows, list):
        raise RuntimeError("gov_info payload missing results list")

    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        if not isinstance(row, dict):
            continue
        park_id = first_non_empty(
            row.get("park_Id"),
            row.get("park_id"),
            row.get("id"),
        )
        if not park_id:
            continue
        result[park_id] = row
    return result


def parse_gov_vacancy_map(payload: Any) -> dict[str, dict[str, Any]]:
    rows = payload.get("car_park") if isinstance(payload, dict) else None
    if not isinstance(rows, list):
        raise RuntimeError("gov_vacancy payload missing car_park list")

    result: dict[str, dict[str, Any]] = {}
    for item in rows:
        if not isinstance(item, dict):
            continue
        park_id = first_non_empty(item.get("park_id"), item.get("park_Id"))
        if not park_id:
            continue
        private_car = pick_gov_vacancy_private_car(item)
        if private_car is None:
            continue
        result[park_id] = private_car
    return result


def parse_ryan_metadata_map(payload: SourcePayload | None) -> dict[str, dict[str, Any]]:
    if payload is None:
        return {}
    rows = payload.data
    if not isinstance(rows, list):
        raise RuntimeError("ryan_metadata payload must be a list")
    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        if not isinstance(row, dict):
            continue
        park_id = first_non_empty(
            row.get("sourceId"),
            row.get("park_Id"),
            row.get("park_id"),
            row.get("id"),
        )
        if not park_id:
            continue
        result[park_id] = row
    return result


def pick_gov_vacancy_private_car(item: dict[str, Any]) -> dict[str, Any] | None:
    vehicle_types = item.get("vehicle_type")
    if not isinstance(vehicle_types, list):
        return None
    for vehicle in vehicle_types:
        if not isinstance(vehicle, dict):
            continue
        if str(vehicle.get("type", "")).upper() != "P":
            continue
        categories = vehicle.get("service_category")
        if not isinstance(categories, list):
            continue
        for category in categories:
            if not isinstance(category, dict):
                continue
            vacancy = to_int(category.get("vacancy"))
            if vacancy is None:
                continue
            return {
                "vacancy": vacancy,
                "vacancy_type": text(category.get("vacancy_type")),
                "lastupdate": text(category.get("lastupdate")),
            }
    return None


def build_normalized_rows(
    *,
    observed_at_iso: str,
    snapshot_id: str,
    gov_info_rows: dict[str, dict[str, Any]],
    gov_vacancy_map: dict[str, dict[str, Any]],
    ryan_map: dict[str, dict[str, Any]],
) -> list[dict[str, Any]]:
    park_ids = sorted(set(gov_info_rows) | set(gov_vacancy_map) | set(ryan_map))
    rows: list[dict[str, Any]] = []

    for park_id in park_ids:
        gov_row = gov_info_rows.get(park_id)
        gov_vacancy = gov_vacancy_map.get(park_id)
        ryan_row = ryan_map.get(park_id)
        gov_private = gov_row.get("privateCar") if isinstance(gov_row, dict) else None
        gov_private = gov_private if isinstance(gov_private, dict) else {}

        gov_info_space = to_int(gov_private.get("space"))
        gov_info_vacancy = to_int(gov_private.get("vacancy"))
        gov_info_space_ev = to_int(gov_private.get("spaceEV"))
        gov_info_space_disabled = to_int(gov_private.get("spaceDIS"))
        gov_info_space_unloading = to_int(gov_private.get("spaceUNL"))
        gov_info_lastupdate = text(gov_private.get("lastupdate"))
        gov_info_vacancy_type = text(gov_private.get("vacancy_type"))

        link_vacancy = to_int(ryan_row.get("linkVacancy")) if ryan_row else None
        link_total_spaces = to_int(ryan_row.get("linkTotalSpaces")) if ryan_row else None
        link_lastupdate = text(ryan_row.get("linkModifiedDate")) if ryan_row else ""

        effective_vacancy = (
            gov_vacancy.get("vacancy")
            if gov_vacancy and gov_vacancy.get("vacancy") is not None
            else gov_info_vacancy
            if gov_info_vacancy is not None
            else link_vacancy
        )
        effective_source = (
            "gov_vacancy_all"
            if gov_vacancy and gov_vacancy.get("vacancy") is not None
            else "gov_info"
            if gov_info_vacancy is not None
            else "link_reit"
            if link_vacancy is not None
            else "none"
        )
        effective_lastupdate = (
            text(gov_vacancy.get("lastupdate"))
            if gov_vacancy and gov_vacancy.get("vacancy") is not None
            else gov_info_lastupdate
            if gov_info_vacancy is not None
            else link_lastupdate
        )

        row = {
            "observed_at": observed_at_iso,
            "snapshot_id": snapshot_id,
            "park_id": park_id,
            "name_en": resolve_name_en(gov_row, ryan_row),
            "name_tc": resolve_name_tc(gov_row, ryan_row),
            "name_sc": resolve_name_sc(gov_row, ryan_row),
            "display_address_en": resolve_address_en(gov_row, ryan_row),
            "display_address_tc": resolve_address_tc(gov_row, ryan_row),
            "district": resolve_district(gov_row, ryan_row),
            "latitude": resolve_latitude(gov_row, ryan_row),
            "longitude": resolve_longitude(gov_row, ryan_row),
            "operator_name": resolve_operator_name(gov_row, ryan_row),
            "nature": text(gov_row.get("nature")) if gov_row else "",
            "carpark_type": text(gov_row.get("carpark_Type")) if gov_row else "",
            "opening_status": resolve_opening_status(gov_row, ryan_row),
            "gov_info_modified_at": text(
                first_non_empty(
                    ryan_row.get("govModifiedDate") if ryan_row else "",
                    gov_row.get("modifiedDate") if gov_row else "",
                )
            ),
            "gov_info_published_at": text(
                first_non_empty(
                    ryan_row.get("govPublishedDate") if ryan_row else "",
                    gov_row.get("publishedDate") if gov_row else "",
                )
            ),
            "gov_info_private_car_space": gov_info_space,
            "gov_info_private_car_vacancy": gov_info_vacancy,
            "gov_info_private_car_space_ev": gov_info_space_ev,
            "gov_info_private_car_space_disabled": gov_info_space_disabled,
            "gov_info_private_car_space_unloading": gov_info_space_unloading,
            "gov_info_private_car_lastupdate": gov_info_lastupdate,
            "gov_info_private_car_vacancy_type": gov_info_vacancy_type,
            "gov_vacancy_private_car_vacancy": (
                gov_vacancy.get("vacancy") if gov_vacancy else None
            ),
            "gov_vacancy_private_car_lastupdate": text(
                gov_vacancy.get("lastupdate") if gov_vacancy else ""
            ),
            "gov_vacancy_private_car_vacancy_type": text(
                gov_vacancy.get("vacancy_type") if gov_vacancy else ""
            ),
            "link_private_car_vacancy": link_vacancy,
            "link_total_spaces": link_total_spaces,
            "link_lastupdate": link_lastupdate,
            "effective_private_car_vacancy": effective_vacancy,
            "effective_private_car_total_spaces": (
                gov_info_space if gov_info_space is not None else link_total_spaces
            ),
            "effective_vacancy_source": effective_source,
            "effective_lastupdate": effective_lastupdate,
            "has_gov_info": gov_row is not None,
            "has_gov_vacancy": gov_vacancy is not None,
            "has_ryan_metadata": ryan_row is not None,
        }
        rows.append(row)
    return rows


def build_manifest(
    *,
    observed_at_iso: str,
    snapshot_id: str,
    normalized_rows: list[dict[str, Any]],
    metered_rows: list[dict[str, Any]],
    latest_normalized_path: Path,
    latest_metered_normalized_path: Path | None,
    archive_normalized_path: Path | None,
    archive_metered_normalized_path: Path | None,
    history_file: Path,
    metered_history_file: Path | None,
    sources: dict[str, SourcePayload],
    raw_paths: dict[str, str],
    errors: list[dict[str, str]],
) -> dict[str, Any]:
    with_effective_vacancy = sum(
        1 for row in normalized_rows if row["effective_private_car_vacancy"] is not None
    )
    with_coordinates = sum(
        1
        for row in normalized_rows
        if row["latitude"] is not None and row["longitude"] is not None
    )
    by_source = {
        source: sum(
            1 for row in normalized_rows if row["effective_vacancy_source"] == source
        )
        for source in ("gov_vacancy_all", "gov_info", "link_reit", "none")
    }

    return {
        "snapshot_id": snapshot_id,
        "observed_at": observed_at_iso,
        "counts": {
            "normalized_rows": len(normalized_rows),
            "metered_rows": len(metered_rows),
            "with_effective_private_car_vacancy": with_effective_vacancy,
            "with_coordinates": with_coordinates,
            "effective_vacancy_source_breakdown": by_source,
        },
        "files": {
            "latest_normalized": str(latest_normalized_path),
            "latest_metered_normalized": str(latest_metered_normalized_path)
            if latest_metered_normalized_path
            else "",
            "archive_normalized": str(archive_normalized_path)
            if archive_normalized_path
            else "",
            "archive_metered_normalized": str(archive_metered_normalized_path)
            if archive_metered_normalized_path
            else "",
            "history_file": str(history_file),
            "metered_history_file": str(metered_history_file)
            if metered_history_file
            else "",
            **raw_paths,
        },
        "sources": {
            name: {
                "url": payload.url,
                "status_code": payload.status_code,
                "fetched_at": payload.fetched_at,
            }
            for name, payload in sources.items()
        },
        "errors": errors,
    }


def resolve_name_en(gov_row: dict[str, Any] | None, ryan_row: dict[str, Any] | None) -> str:
    names = string_map(ryan_row.get("namesByLang") if ryan_row else None)
    return text(
        first_non_empty(
            names.get("en_US"),
            names.get("en"),
            ryan_row.get("linkNameEn") if ryan_row else "",
            ryan_row.get("nameEn") if ryan_row else "",
            gov_row.get("name") if gov_row else "",
            ryan_row.get("name") if ryan_row else "",
        )
    )


def resolve_name_tc(gov_row: dict[str, Any] | None, ryan_row: dict[str, Any] | None) -> str:
    names = string_map(ryan_row.get("namesByLang") if ryan_row else None)
    return text(
        first_non_empty(
            names.get("zh_HK"),
            names.get("zh_TW"),
            names.get("tc"),
            names.get("zh"),
            ryan_row.get("linkNameTc") if ryan_row else "",
            gov_row.get("name") if gov_row else "",
            ryan_row.get("name") if ryan_row else "",
        )
    )


def resolve_name_sc(gov_row: dict[str, Any] | None, ryan_row: dict[str, Any] | None) -> str:
    names = string_map(ryan_row.get("namesByLang") if ryan_row else None)
    return text(
        first_non_empty(
            names.get("zh_CN"),
            names.get("cn"),
            names.get("zh"),
            ryan_row.get("govNameSc") if ryan_row else "",
            resolve_name_tc(gov_row, ryan_row),
            gov_row.get("name") if gov_row else "",
            ryan_row.get("name") if ryan_row else "",
        )
    )


def resolve_address_en(
    gov_row: dict[str, Any] | None,
    ryan_row: dict[str, Any] | None,
) -> str:
    addresses = string_map(ryan_row.get("displayAddressesByLang") if ryan_row else None)
    return text(
        first_non_empty(
            addresses.get("en_US"),
            addresses.get("en"),
            ryan_row.get("linkAddressEn") if ryan_row else "",
            gov_row.get("displayAddress") if gov_row else "",
            gov_row.get("address") if gov_row else "",
            ryan_row.get("address") if ryan_row else "",
        )
    )


def resolve_address_tc(
    gov_row: dict[str, Any] | None,
    ryan_row: dict[str, Any] | None,
) -> str:
    addresses = string_map(ryan_row.get("displayAddressesByLang") if ryan_row else None)
    return text(
        first_non_empty(
            addresses.get("zh_HK"),
            addresses.get("zh_TW"),
            addresses.get("tc"),
            addresses.get("zh"),
            ryan_row.get("linkAddressTc") if ryan_row else "",
            gov_row.get("displayAddress") if gov_row else "",
            gov_row.get("address") if gov_row else "",
            ryan_row.get("address") if ryan_row else "",
        )
    )


def resolve_district(
    gov_row: dict[str, Any] | None,
    ryan_row: dict[str, Any] | None,
) -> str:
    return text(
        first_non_empty(
            ryan_row.get("district") if ryan_row else "",
            gov_row.get("district") if gov_row else "",
        )
    )


def resolve_latitude(
    gov_row: dict[str, Any] | None,
    ryan_row: dict[str, Any] | None,
) -> float | None:
    return to_float(
        first_non_empty(
            ryan_row.get("lat") if ryan_row else None,
            gov_row.get("latitude") if gov_row else None,
            gov_row.get("lat") if gov_row else None,
        )
    )


def resolve_longitude(
    gov_row: dict[str, Any] | None,
    ryan_row: dict[str, Any] | None,
) -> float | None:
    return to_float(
        first_non_empty(
            ryan_row.get("lng") if ryan_row else None,
            gov_row.get("longitude") if gov_row else None,
            gov_row.get("lng") if gov_row else None,
        )
    )


def resolve_operator_name(
    gov_row: dict[str, Any] | None,
    ryan_row: dict[str, Any] | None,
) -> str:
    return text(
        first_non_empty(
            ryan_row.get("operator") if ryan_row else "",
            gov_row.get("operator") if gov_row else "",
        )
    )


def resolve_opening_status(
    gov_row: dict[str, Any] | None,
    ryan_row: dict[str, Any] | None,
) -> str:
    return text(
        first_non_empty(
            gov_row.get("opening_status") if gov_row else "",
            ryan_row.get("govOpeningStatus") if ryan_row else "",
        )
    )


def build_metered_rows(
    *,
    observed_at_iso: str,
    snapshot_id: str,
    meter_space_csv: str,
    meter_occupancy_csv: str,
) -> list[dict[str, Any]]:
    spaces = parse_meter_space_rows(meter_space_csv)
    occupancy = parse_meter_occupancy_map(meter_occupancy_csv)
    rows: list[dict[str, Any]] = []
    for space in spaces:
        status = occupancy.get(space["parking_space_id"], {})
        occupancy_code = text(status.get("occupancy_status"))
        rows.append(
            {
                "observed_at": observed_at_iso,
                "snapshot_id": snapshot_id,
                "parking_space_id": space["parking_space_id"],
                "pole_id": text(space.get("pole_id")),
                "region_en": text(space.get("region_en")),
                "region_tc": text(space.get("region_tc")),
                "region_sc": text(space.get("region_sc")),
                "district_en": text(space.get("district_en")),
                "district_tc": text(space.get("district_tc")),
                "district_sc": text(space.get("district_sc")),
                "subdistrict_en": text(space.get("subdistrict_en")),
                "subdistrict_tc": text(space.get("subdistrict_tc")),
                "subdistrict_sc": text(space.get("subdistrict_sc")),
                "street_en": text(space.get("street_en")),
                "street_tc": text(space.get("street_tc")),
                "street_sc": text(space.get("street_sc")),
                "section_en": text(space.get("section_en")),
                "section_tc": text(space.get("section_tc")),
                "section_sc": text(space.get("section_sc")),
                "latitude": to_float(space.get("latitude")),
                "longitude": to_float(space.get("longitude")),
                "vehicle_type": text(space.get("vehicle_type")),
                "operating_period": text(space.get("operating_period")),
                "time_unit_minutes": to_int(space.get("time_unit")),
                "payment_unit_hkd": to_float(space.get("payment_unit")),
                "lpp_minutes": to_int(space.get("lpp")),
                "parking_meter_status": text(status.get("parking_meter_status")),
                "occupancy_status": occupancy_code,
                "occupancy_label": meter_occupancy_label(occupancy_code),
                "occupancy_changed_at": text(status.get("occupancy_changed_at")),
                "has_occupancy": bool(status),
            }
        )
    return rows


def parse_meter_space_rows(csv_text: str) -> list[dict[str, str]]:
    lines = csv_text.splitlines()
    if len(lines) <= 2:
        return []
    reader = csv.DictReader(lines[2:])
    rows: list[dict[str, str]] = []
    for row in reader:
        if not row:
            continue
        parking_space_id = text(row.get("ParkingSpaceId"))
        if not parking_space_id:
            continue
        rows.append(
            {
                "pole_id": text(row.get("PoleId")),
                "parking_space_id": parking_space_id,
                "region_en": text(row.get("Region")),
                "region_tc": text(row.get("Region_tc")),
                "region_sc": text(row.get("Region_sc")),
                "district_en": text(row.get("District")),
                "district_tc": text(row.get("District_tc")),
                "district_sc": text(row.get("District_sc")),
                "subdistrict_en": text(row.get("SubDistrict")),
                "subdistrict_tc": text(row.get("SubDistrict_tc")),
                "subdistrict_sc": text(row.get("SubDistrict_sc")),
                "street_en": text(row.get("Street")),
                "street_tc": text(row.get("Street_tc")),
                "street_sc": text(row.get("Street_sc")),
                "section_en": text(row.get("SectionOfStreet")),
                "section_tc": text(row.get("SectionOfStreet_tc")),
                "section_sc": text(row.get("SectionOfStreet_sc")),
                "latitude": text(row.get("Latitude")),
                "longitude": text(row.get("Longitude")),
                "vehicle_type": text(row.get("VehicleType")),
                "lpp": text(row.get("LPP")),
                "operating_period": text(row.get("OperatingPeriod")),
                "time_unit": text(row.get("TimeUnit")),
                "payment_unit": text(row.get("PaymentUnit")),
            }
        )
    return rows


def parse_meter_occupancy_map(csv_text: str) -> dict[str, dict[str, str]]:
    reader = csv.DictReader(csv_text.splitlines())
    result: dict[str, dict[str, str]] = {}
    for row in reader:
        if not row:
            continue
        parking_space_id = text(row.get("ParkingSpaceId"))
        if not parking_space_id:
            continue
        result[parking_space_id] = {
            "parking_meter_status": text(row.get("ParkingMeterStatus")),
            "occupancy_status": text(row.get("OccupancyStatus")),
            "occupancy_changed_at": text(row.get("OccupancyDateChanged")),
        }
    return result


def meter_occupancy_label(code: str) -> str:
    return {
        "V": "vacant",
        "O": "occupied",
    }.get(code, "unknown")


def write_jsonl(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")


def append_jsonl(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")


def first_non_empty(*values: Any) -> Any:
    for value in values:
        if value is None:
            continue
        if isinstance(value, str):
            stripped = value.strip()
            if stripped:
                return stripped
            continue
        return value
    return ""


def text(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def to_int(value: Any) -> int | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return None


def to_float(value: Any) -> float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value).strip())
    except (TypeError, ValueError):
        return None


def string_map(value: Any) -> dict[str, str]:
    if not isinstance(value, dict):
        return {}
    result: dict[str, str] = {}
    for key, item in value.items():
        if item is None:
            continue
        result[str(key)] = str(item).strip()
    return result


if __name__ == "__main__":
    raise SystemExit(main())
