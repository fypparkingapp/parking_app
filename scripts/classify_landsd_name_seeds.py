#!/usr/bin/env python3
"""Classify raw LandsD name seeds into category-specific text files.

Example:
  python3 scripts/classify_landsd_name_seeds.py \
    --input scripts/landsd_name_seeds/major_destinations_1000.txt \
    --output-dir scripts/landsd_name_seeds/classified
"""

from __future__ import annotations

import argparse
from pathlib import Path


CATEGORY_RULES = [
    (
        "campuses.txt",
        [
            " university",
            " college",
            " campus",
            " institute of ",
            "大學",
            "學院",
            "書院",
            "校園",
        ],
    ),
    (
        "schools.txt",
        [
            " school",
            " kindergarten",
            " academy",
            " college preparatory",
            "學校",
            "中學",
            "小學",
            "幼稚園",
            "書院",
        ],
    ),
    (
        "hospitals.txt",
        [
            " hospital",
            " clinic",
            " medical centre",
            " medical center",
            " health centre",
            "醫院",
            "診所",
            "醫療",
            "健康中心",
        ],
    ),
    (
        "government_offices.txt",
        [
            " government",
            " law courts",
            " magistracy",
            " police",
            " fire station",
            " post office",
            "政府",
            "法院",
            "裁判署",
            "警署",
            "消防局",
            "入境事務",
            "稅務大樓",
            "政務",
        ],
    ),
    (
        "hotels.txt",
        [
            " hotel",
            " hostel",
            " resort",
            " lodge",
            "酒店",
            "賓館",
            "度假",
            "旅舍",
        ],
    ),
    (
        "malls.txt",
        [
            " mall",
            " plaza",
            " arcade",
            " shopping centre",
            " shopping center",
            " retail",
            " department store",
            "廣場",
            "商場",
            "中心",
            "百貨",
            "名店",
        ],
    ),
    (
        "housing_estates.txt",
        [
            " estate",
            " garden",
            " gardens",
            " villa",
            " mansion",
            " court",
            " terrace",
            " residence",
            " residence",
            "苑",
            "花園",
            "邨",
            "居",
            "閣",
            "軒",
            "臺",
            "台",
            "居",
            "村",
        ],
    ),
    (
        "office_towers.txt",
        [
            " tower",
            " centre",
            " center",
            " building",
            " house",
            " offices",
            " commercial",
            "大廈",
            "中心",
            "商業",
            "寫字樓",
            "大樓",
            "中心",
        ],
    ),
    (
        "industrial_areas.txt",
        [
            " industrial",
            " factory",
            " warehouse",
            "工業",
            "工貿",
            "貨倉",
            "倉",
        ],
    ),
    (
        "arts_venues.txt",
        [
            " museum",
            " theatre",
            " theater",
            " gallery",
            " stadium",
            " arena",
            " coliseum",
            "藝術",
            "文化",
            "博物館",
            "劇院",
            "戲院",
            "展覽館",
            "體育館",
        ],
    ),
    (
        "theme_parks.txt",
        [
            " theme park",
            " amusement",
            " disney",
            " ocean park",
            "主題公園",
            "樂園",
            "海洋公園",
        ],
    ),
]

FALLBACK_FILE = "major_destinations.txt"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Classify LandsD plain-name seeds into category text files.",
    )
    parser.add_argument("--input", required=True, help="Input .txt file")
    parser.add_argument("--output-dir", required=True, help="Output directory")
    args = parser.parse_args()

    source = Path(args.input)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    buckets = {filename: [] for filename, _ in CATEGORY_RULES}
    buckets[FALLBACK_FILE] = []

    for raw_line in source.read_text(encoding="utf-8").splitlines():
        name = normalize_name(raw_line)
        if not name:
            continue
        target = classify_name(name)
        buckets[target].append(name)

    for filename, names in buckets.items():
        deduped = dedupe_preserve_order(names)
        path = output_dir / filename
        path.write_text("\n".join(deduped) + ("\n" if deduped else ""), encoding="utf-8")
        print(f"{filename}: {len(deduped)}")
    return 0


def classify_name(name: str) -> str:
    lowered = f" {name.casefold()} "
    for filename, keywords in CATEGORY_RULES:
        for keyword in keywords:
            if contains_keyword(lowered, name, keyword):
                return filename
    return FALLBACK_FILE


def contains_keyword(lowered_name: str, original_name: str, keyword: str) -> bool:
    keyword = keyword.strip()
    if not keyword:
        return False
    if any("\u4e00" <= ch <= "\u9fff" for ch in keyword):
        return keyword in original_name
    return f" {keyword.casefold()} " in lowered_name or keyword.casefold() in lowered_name


def dedupe_preserve_order(values: list[str]) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for value in values:
        key = value.casefold()
        if key in seen:
            continue
        seen.add(key)
        out.append(value)
    return out


def normalize_name(raw_line: str) -> str:
    line = raw_line.strip()
    if not line or line.startswith("#"):
        return ""
    return " ".join(line.split())


if __name__ == "__main__":
    raise SystemExit(main())
