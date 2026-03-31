#!/usr/bin/env python3
"""Generate LandsD batch CSV from plain name lists.

Examples:
  python3 scripts/generate_landsd_batch_csv.py \
    --names-file scripts/landsd_name_seeds/major_destinations_1000.txt \
    --subcategory majorDestination \
    --output tmp/landsd_batch_1000.csv

  python3 scripts/generate_landsd_batch_csv.py \
    --names-dir scripts/landsd_name_seeds \
    --output tmp/landsd_batch_all.csv
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path


DIR_FILE_TO_SUBCATEGORY = {
    "campuses.txt": "campus",
    "schools.txt": "school",
    "malls.txt": "mall",
    "major_destinations.txt": "majorDestination",
    "major_destinations_1000.txt": "majorDestination",
    "office_towers.txt": "officeTower",
    "industrial_areas.txt": "industrialArea",
    "housing_estates.txt": "housingEstate",
    "hospitals.txt": "hospital",
    "government_offices.txt": "governmentOffice",
    "hotels.txt": "hotel",
    "theme_parks.txt": "themePark",
    "arts_venues.txt": "artsVenue",
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

CSV_HEADERS = [
    "label",
    "query",
    "subcategory",
    "exact_name",
    "name_contains",
    "district",
    "aliases_en",
    "aliases_zh",
    "append_to",
    "limit",
    "enabled",
]

DEFAULT_SUBCATEGORY_ORDER = [
    "officeTower",
    "mall",
    "hospital",
    "hotel",
    "governmentOffice",
    "school",
    "campus",
    "artsVenue",
    "themePark",
    "majorDestination",
    "industrialArea",
    "housingEstate",
]

NORMALIZE_PATTERN = re.compile(r"[^a-z0-9+\u3400-\u9FFF]")


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    subcategory_limits = parse_subcategory_limits(args.subcategory_limit)
    subcategory_order = parse_subcategory_order(args.subcategory_order)

    rows: list[dict[str, str]] = []
    if args.names_file:
        if not args.subcategory:
            raise SystemExit("--subcategory is required with --names-file")
        rows.extend(
            build_rows_from_file(
                Path(args.names_file),
                subcategory=args.subcategory,
                default_limit=args.limit,
            )
        )
    else:
        rows.extend(
            build_rows_from_dir(
                Path(args.names_dir),
                default_limit=args.limit,
            )
        )

    rows = dedupe_rows(rows)
    skipped_existing = 0
    if args.skip_existing:
        rows, skipped_existing = filter_existing_rows(rows)
    skipped_batch_rows = 0
    if args.skip_batch_csv:
        rows, skipped_batch_rows = filter_batch_rows(
            rows,
            batch_paths=[Path(value) for value in args.skip_batch_csv],
        )
    rows = sort_rows(rows, subcategory_order=subcategory_order)
    rows = apply_subcategory_limits(rows, subcategory_limits=subcategory_limits)

    output_path = Path(args.output)
    written_files = write_output(
        rows,
        output_path=output_path,
        split_size=args.split_size,
    )
    summary = build_summary(
        rows,
        written_files=written_files,
        skipped_existing=skipped_existing,
        skipped_batch_rows=skipped_batch_rows,
    )
    if args.summary_json:
        summary_path = Path(args.summary_json)
        summary_path.parent.mkdir(parents=True, exist_ok=True)
        summary_path.write_text(
            json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"Wrote summary to {summary_path}")

    for path, count in written_files:
        print(f"Wrote {count} batch row(s) to {path}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate LandsD batch CSV from plain-text name lists.",
    )
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument(
        "--names-file",
        help="Plain text file with one place name per line.",
    )
    source.add_argument(
        "--names-dir",
        help="Directory of .txt files. Filenames map to subcategories.",
    )
    parser.add_argument(
        "--subcategory",
        help="Subcategory for --names-file mode.",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Output CSV path.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=1,
        help="Default per-row LandsD result limit.",
    )
    parser.add_argument(
        "--split-size",
        type=int,
        default=0,
        help="Write numbered CSV shards with at most this many rows each.",
    )
    parser.add_argument(
        "--subcategory-limit",
        action="append",
        default=[],
        help="Cap rows per subcategory, e.g. officeTower=1200. Can repeat.",
    )
    parser.add_argument(
        "--subcategory-order",
        default=",".join(DEFAULT_SUBCATEGORY_ORDER),
        help="Comma-separated subcategory priority order for output rows.",
    )
    parser.add_argument(
        "--summary-json",
        help="Optional JSON path for row-count summary.",
    )
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        help="Skip rows whose name already exists in the current landmark JSON files.",
    )
    parser.add_argument(
        "--skip-batch-csv",
        action="append",
        default=[],
        help="Skip rows already present in a previously generated batch CSV. Can repeat.",
    )
    return parser


def build_rows_from_dir(directory: Path, *, default_limit: int) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for path in sorted(directory.glob("*.txt")):
        subcategory = DIR_FILE_TO_SUBCATEGORY.get(path.name)
        if not subcategory:
            continue
        rows.extend(
            build_rows_from_file(
                path,
                subcategory=subcategory,
                default_limit=default_limit,
            )
        )
    return rows


def build_rows_from_file(
    path: Path,
    *,
    subcategory: str,
    default_limit: int,
) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        name = normalize_name(raw_line)
        if not name:
            continue
        rows.append(
            {
                "label": name,
                "query": name,
                "subcategory": subcategory,
                "exact_name": name,
                "name_contains": "",
                "district": "",
                "aliases_en": "",
                "aliases_zh": "",
                "append_to": "",
                "limit": str(default_limit),
                "enabled": "true",
            }
        )
    return rows


def dedupe_rows(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    deduped: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for row in rows:
        key = (
            row["subcategory"].casefold(),
            row["query"].casefold(),
        )
        if key in seen:
            continue
        seen.add(key)
        deduped.append(row)
    return deduped


def filter_existing_rows(rows: list[dict[str, str]]) -> tuple[list[dict[str, str]], int]:
    existing_names = load_global_existing_names(rows)
    filtered: list[dict[str, str]] = []
    skipped = 0

    for row in rows:
        row_names = {
            normalize_existing_name(row.get("query", "")),
            normalize_existing_name(row.get("exact_name", "")),
            normalize_existing_name(row.get("label", "")),
        }
        row_names.discard("")
        if row_names and not row_names.isdisjoint(existing_names):
            skipped += 1
            continue
        filtered.append(row)

    return filtered, skipped


def filter_batch_rows(
    rows: list[dict[str, str]],
    *,
    batch_paths: list[Path],
) -> tuple[list[dict[str, str]], int]:
    skipped_names = load_batch_names(batch_paths)
    filtered: list[dict[str, str]] = []
    skipped = 0

    for row in rows:
        row_names = {
            normalize_existing_name(row.get("query", "")),
            normalize_existing_name(row.get("exact_name", "")),
            normalize_existing_name(row.get("label", "")),
        }
        row_names.discard("")
        if row_names and not row_names.isdisjoint(skipped_names):
            skipped += 1
            continue
        filtered.append(row)

    return filtered, skipped


def load_global_existing_names(rows: list[dict[str, str]]) -> set[str]:
    paths = {
        Path(path)
        for path in DEFAULT_OUTPUT_BY_SUBCATEGORY.values()
    }
    for row in rows:
        append_to = row.get("append_to", "").strip()
        if append_to:
            paths.add(Path(append_to))

    names: set[str] = set()
    for path in paths:
        names.update(load_existing_names(path))
    return names


def load_existing_names(path: Path) -> set[str]:
    if not path.exists():
        return set()

    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise SystemExit(f"{path} does not contain a JSON list.")

    names: set[str] = set()
    for item in data:
        if not isinstance(item, dict):
            continue
        for key in ("displayName", "nameEn", "nameZh"):
            normalized = normalize_existing_name(item.get(key, ""))
            if normalized:
                names.add(normalized)
    return names


def load_batch_names(paths: list[Path]) -> set[str]:
    names: set[str] = set()
    for path in paths:
        if not path.exists():
            continue
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            for row in reader:
                if row is None:
                    continue
                for key in ("query", "exact_name", "label"):
                    normalized = normalize_existing_name(row.get(key, ""))
                    if normalized:
                        names.add(normalized)
    return names


def normalize_existing_name(value: object) -> str:
    text = str(value).strip().lower()
    if not text:
        return ""
    return NORMALIZE_PATTERN.sub("", text)


def sort_rows(
    rows: list[dict[str, str]],
    *,
    subcategory_order: list[str],
) -> list[dict[str, str]]:
    order_index = {
        name: index
        for index, name in enumerate(subcategory_order)
    }
    return sorted(
        rows,
        key=lambda row: (
            order_index.get(row["subcategory"], len(order_index)),
            row["subcategory"].casefold(),
            row["query"].casefold(),
        ),
    )


def apply_subcategory_limits(
    rows: list[dict[str, str]],
    *,
    subcategory_limits: dict[str, int],
) -> list[dict[str, str]]:
    if not subcategory_limits:
        return rows

    counts: dict[str, int] = {}
    limited: list[dict[str, str]] = []
    for row in rows:
        subcategory = row["subcategory"]
        limit = subcategory_limits.get(subcategory)
        if limit is not None and counts.get(subcategory, 0) >= limit:
            continue
        limited.append(row)
        counts[subcategory] = counts.get(subcategory, 0) + 1
    return limited


def parse_subcategory_limits(values: list[str]) -> dict[str, int]:
    limits: dict[str, int] = {}
    for raw in values:
        text = raw.strip()
        if not text:
            continue
        name, separator, count_text = text.partition("=")
        if separator != "=":
            raise SystemExit(
                f"Invalid --subcategory-limit '{raw}'. Expected format subcategory=count."
            )
        subcategory = name.strip()
        if subcategory not in DIR_FILE_TO_SUBCATEGORY.values():
            raise SystemExit(f"Unknown subcategory in --subcategory-limit: {subcategory}")
        try:
            count = int(count_text.strip())
        except ValueError as exc:
            raise SystemExit(
                f"Invalid limit in --subcategory-limit '{raw}'."
            ) from exc
        if count < 0:
            raise SystemExit(
                f"Invalid negative limit in --subcategory-limit '{raw}'."
            )
        limits[subcategory] = count
    return limits


def parse_subcategory_order(raw: str) -> list[str]:
    if not raw.strip():
        return list(DEFAULT_SUBCATEGORY_ORDER)
    order = [item.strip() for item in raw.split(",") if item.strip()]
    valid_subcategories = set(DIR_FILE_TO_SUBCATEGORY.values())
    invalid = [item for item in order if item not in valid_subcategories]
    if invalid:
        raise SystemExit(
            "Unknown subcategory in --subcategory-order: "
            + ", ".join(sorted(set(invalid)))
        )
    return order


def write_output(
    rows: list[dict[str, str]],
    *,
    output_path: Path,
    split_size: int,
) -> list[tuple[Path, int]]:
    if split_size <= 0:
        write_rows(output_path, rows)
        return [(output_path, len(rows))]

    written_files: list[tuple[Path, int]] = []
    index = 0
    shard_number = 1
    while index < len(rows):
        shard_rows = rows[index : index + split_size]
        shard_path = output_path.with_name(
            f"{output_path.stem}_{shard_number:03d}{output_path.suffix or '.csv'}"
        )
        write_rows(shard_path, shard_rows)
        written_files.append((shard_path, len(shard_rows)))
        index += split_size
        shard_number += 1
    if not written_files:
        empty_path = output_path.with_name(
            f"{output_path.stem}_001{output_path.suffix or '.csv'}"
        )
        write_rows(empty_path, [])
        written_files.append((empty_path, 0))
    return written_files


def write_rows(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_HEADERS)
        writer.writeheader()
        writer.writerows(rows)


def build_summary(
    rows: list[dict[str, str]],
    *,
    written_files: list[tuple[Path, int]],
    skipped_existing: int = 0,
    skipped_batch_rows: int = 0,
) -> dict[str, object]:
    counts: dict[str, int] = {}
    for row in rows:
        subcategory = row["subcategory"]
        counts[subcategory] = counts.get(subcategory, 0) + 1
    return {
        "totalRows": len(rows),
        "skippedExistingRows": skipped_existing,
        "skippedBatchRows": skipped_batch_rows,
        "subcategoryCounts": dict(sorted(counts.items())),
        "writtenFiles": [
            {"path": str(path), "rows": count}
            for path, count in written_files
        ],
    }


def normalize_name(raw_line: str) -> str:
    line = raw_line.strip()
    if not line or line.startswith("#"):
        return ""
    return " ".join(line.split())


if __name__ == "__main__":
    raise SystemExit(main())
