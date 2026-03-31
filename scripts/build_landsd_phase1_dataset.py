#!/usr/bin/env python3
"""Build a larger phase-1 LandsD search dataset toward target category counts."""

from __future__ import annotations

import argparse
import concurrent.futures
import csv
import json
import string
import time
import urllib.parse
import urllib.request
from pathlib import Path


API_BASE = "https://www.map.gov.hk/gs/api/v1.0.0/locationSearch"
REQUEST_HEADERS = {
    "User-Agent": "Mozilla/5.0",
    "Accept": "application/json, text/plain, */*",
    "Referer": "https://www.map.gov.hk/gm/",
    "Origin": "https://www.map.gov.hk",
    "Accept-Language": "en-US,en;q=0.9,zh-HK;q=0.8,zh;q=0.7",
}

TARGETS = {
    "housing_estates.txt": 99999,
    "malls.txt": 99999,
    "office_towers.txt": 99999,
    "industrial_areas.txt": 99999,
    "campuses.txt": 99999,
    "schools.txt": 99999,
    "hospitals.txt": 99999,
    "government_offices.txt": 99999,
    "hotels.txt": 99999,
    "arts_venues.txt": 99999,
    "theme_parks.txt": 99999,
    "major_destinations.txt": 99999,
}

PHASE2_TARGETS = {
    "housing_estates.txt": 99999,
    "malls.txt": 99999,
    "office_towers.txt": 99999,
    "industrial_areas.txt": 99999,
    "campuses.txt": 99999,
    "schools.txt": 99999,
    "hospitals.txt": 99999,
    "government_offices.txt": 99999,
    "hotels.txt": 99999,
    "arts_venues.txt": 99999,
    "theme_parks.txt": 99999,
    "major_destinations.txt": 99999,
}

DIR_FILE_TO_SUBCATEGORY = {
    "campuses.txt": "campus",
    "schools.txt": "school",
    "malls.txt": "mall",
    "major_destinations.txt": "majorDestination",
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
            "學校",
            "中學",
            "小學",
            "幼稚園",
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
            " customs",
            " immigration",
            "政府",
            "法院",
            "裁判署",
            "警署",
            "消防局",
            "入境事務",
            "海關",
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
            " outlet",
            "廣場",
            "商場",
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
            "苑",
            "花園",
            "邨",
            "居",
            "閣",
            "軒",
            "臺",
            "台",
            "村",
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
            "工廈",
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
            "商業",
            "寫字樓",
            "大樓",
            "中心",
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
            " arts",
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

BAD_EN_SUBSTRINGS = [
    " station",
    " road",
    " street",
    " avenue",
    " path",
    " trail",
    " lane",
    " footbridge",
    " sitting-out area",
    " nullah",
    " hotspot",
    " wi-fi.hk",
    " ipostal",
    " post office",
    " public toilet",
    " refuse collection point",
    " bus stop",
    " minibus stop",
    " taxi stand",
    " loading bay",
    " subway",
    " lift lobby",
    " lobby",
    " entrance",
    " exit",
    " near ",
]

BAD_ZH_SUBSTRINGS = [
    "站",
    "道",
    "街",
    "路",
    "里",
    "巷",
    "徑",
    "天橋",
    "公廁",
    "巴士站",
    "小巴站",
    "的士站",
    "郵政局",
    "智郵站",
    "垃圾收集站",
    "投注站",
    "幹線",
    "交匯處",
    "迴旋處",
    "隧道",
    "洗手間",
    "大堂",
    "入口",
    "出口",
    "附近",
]

CHINESE_SEEDS = list(
    "中大新東西南北港九沙荃葵青元旺深灣山海天嘉麗寶華金銀德樂景偉宏康雅豪富美翠盈昌安盛榮峰富翠海灣城園苑軒閣邨居廣場中心商場大廈酒店醫院學校大學書院工業"
)

ENGLISH_CATEGORY_SEEDS = [
    "plaza",
    "mall",
    "centre",
    "center",
    "tower",
    "building",
    "house",
    "estate",
    "garden",
    "court",
    "villa",
    "mansion",
    "school",
    "college",
    "university",
    "hospital",
    "clinic",
    "government",
    "hotel",
    "museum",
    "theatre",
    "stadium",
    "park",
    "arcade",
    "harbour",
    "industrial",
    "commercial",
]

ENGLISH_DISTRICT_SEEDS = [
    "central",
    "admiralty",
    "wan chai",
    "causeway bay",
    "north point",
    "quarry bay",
    "tai koo",
    "kennedy town",
    "sheung wan",
    "tsim sha tsui",
    "mong kok",
    "jordan",
    "yau ma tei",
    "sham shui po",
    "kwun tong",
    "kowloon bay",
    "wong tai sin",
    "kowloon tong",
    "sha tin",
    "tai wai",
    "tsuen wan",
    "kwai chung",
    "tuen mun",
    "yuen long",
    "tai po",
    "fanling",
    "sheung shui",
    "tseung kwan o",
    "sai kung",
]

ZH_DISTRICT_SEEDS = [
    "中環",
    "金鐘",
    "灣仔",
    "銅鑼灣",
    "北角",
    "鰂魚涌",
    "太古",
    "堅尼地城",
    "上環",
    "尖沙咀",
    "旺角",
    "佐敦",
    "油麻地",
    "深水埗",
    "觀塘",
    "九龍灣",
    "黃大仙",
    "九龍塘",
    "沙田",
    "大圍",
    "荃灣",
    "葵涌",
    "屯門",
    "元朗",
    "大埔",
    "粉嶺",
    "上水",
    "將軍澳",
    "西貢",
]

PHASE2_ENGLISH_SUFFIXES = [
    "plaza",
    "mall",
    "centre",
    "tower",
    "building",
    "house",
    "estate",
    "garden",
    "court",
    "residence",
    "residences",
    "hotel",
    "school",
    "college",
    "academy",
    "commercial",
    "industrial",
    "galleria",
    "pavilion",
]

PHASE2_ENGLISH_MODIFIERS = [
    "grand",
    "metro",
    "city",
    "central",
    "harbour",
    "harbor",
    "island",
    "royal",
    "garden",
    "international",
    "discovery",
    "fortune",
    "prosperity",
    "pacific",
    "golden",
    "silver",
    "sky",
]

PHASE2_CHINESE_SUFFIXES = [
    "廣場",
    "商場",
    "中心",
    "大廈",
    "大樓",
    "花園",
    "苑",
    "邨",
    "閣",
    "軒",
    "酒店",
    "學校",
    "書院",
    "工業",
    "工貿",
    "商業",
]

PHASE2_CHINESE_PREFIXES = [
    "康",
    "安",
    "盛",
    "榮",
    "峰",
    "富",
    "翠",
    "雅",
    "豪",
    "寶",
    "盈",
    "昌",
    "朗",
    "御",
    "海",
    "天",
    "帝",
    "皇",
]

TARGETS_BY_PROFILE = {
    "phase1": TARGETS,
    "phase2": PHASE2_TARGETS,
}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build a larger phase-1 LandsD search dataset.",
    )
    parser.add_argument(
        "--profile",
        choices=sorted(TARGETS_BY_PROFILE.keys()),
        default="phase1",
        help="Harvest profile. phase2 uses broader seeds and larger targets.",
    )
    parser.add_argument(
        "--output-dir",
        default="scripts/landsd_name_seeds/phase1_targets",
        help="Directory for generated category text files.",
    )
    parser.add_argument(
        "--batch-csv",
        default="scripts/landsd_phase1_batch.csv",
        help="Output batch CSV path.",
    )
    parser.add_argument(
        "--summary-json",
        default="scripts/landsd_phase1_summary.json",
        help="Output summary JSON path.",
    )
    parser.add_argument(
        "--sleep-ms",
        type=int,
        default=120,
        help="Pause between requests in milliseconds.",
    )
    parser.add_argument(
        "--max-seeds",
        type=int,
        default=0,
        help="Only process the first N generated seeds.",
    )
    parser.add_argument(
        "--progress-every",
        type=int,
        default=25,
        help="Print progress every N processed seeds.",
    )
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        help="Skip names already present in current asset landmark JSON files.",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=1,
        help="Number of parallel workers for fetching seed queries.",
    )
    args = parser.parse_args()

    targets = TARGETS_BY_PROFILE[args.profile]
    seeds = build_query_seeds(profile=args.profile)
    if args.max_seeds > 0:
        seeds = seeds[: args.max_seeds]

    buckets = {filename: [] for filename in targets}
    seen_by_bucket = {filename: set() for filename in targets}
    seed_progress = []
    existing_names = load_existing_names() if args.skip_existing else set()
    skipped_existing = 0

    workers = max(1, int(args.workers))
    seed_hits: list[list[dict]] = [[] for _ in seeds]
    if workers == 1:
        for index, seed in enumerate(seeds, start=1):
            seed_hits[index - 1] = fetch_locations(seed)
            if args.progress_every > 0 and index % args.progress_every == 0:
                print(f"[fetch {index}/{len(seeds)}]", flush=True)
            if args.sleep_ms > 0 and index != len(seeds):
                time.sleep(args.sleep_ms / 1000.0)
    else:
        print(f"Fetching with {workers} parallel worker(s).", flush=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
            future_map = {
                executor.submit(fetch_locations, seed): index
                for index, seed in enumerate(seeds)
            }
            completed = 0
            for future in concurrent.futures.as_completed(future_map):
                index = future_map[future]
                seed = seeds[index]
                try:
                    seed_hits[index] = future.result()
                except Exception as exc:  # pragma: no cover - network resilience
                    seed_hits[index] = []
                    print(f"[warn] seed={seed!r} fetch failed: {exc}", flush=True)
                completed += 1
                if args.progress_every > 0 and completed % args.progress_every == 0:
                    print(f"[fetch {completed}/{len(seeds)}]", flush=True)

    for index, (seed, hits) in enumerate(zip(seeds, seed_hits), start=1):
        accepted = 0
        skipped_for_seed = 0
        for hit in hits:
            name = preferred_name(hit.get("nameEN", ""), hit.get("nameZH", ""))
            if not is_candidate_name(name):
                continue
            normalized_name = name.casefold()
            if normalized_name in existing_names:
                skipped_existing += 1
                skipped_for_seed += 1
                continue
            bucket = classify_name(name)
            if bucket not in targets:
                continue
            if len(buckets[bucket]) >= targets[bucket]:
                continue
            if normalized_name in seen_by_bucket[bucket]:
                continue
            seen_by_bucket[bucket].add(normalized_name)
            buckets[bucket].append(name)
            accepted += 1
        seed_progress.append(
            {
                "seed": seed,
                "hits": len(hits),
                "accepted": accepted,
                "skippedExisting": skipped_for_seed,
            }
        )
        if args.progress_every > 0 and index % args.progress_every == 0:
            print(
                f"[process {index}/{len(seeds)}] total={sum(len(values) for values in buckets.values())}",
                flush=True,
            )
        if all(len(buckets[name]) >= targets[name] for name in targets):
            break

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    for filename, values in buckets.items():
        path = output_dir / filename
        path.write_text("\n".join(values) + ("\n" if values else ""), encoding="utf-8")

    write_batch_csv(Path(args.batch_csv), buckets)
    summary = build_summary(
        profile=args.profile,
        seeds_processed=len(seed_progress),
        buckets=buckets,
        seed_progress=seed_progress,
        targets=targets,
        skipped_existing=skipped_existing,
    )
    summary_path = Path(args.summary_json)
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps(summary["counts"], ensure_ascii=False, indent=2))
    return 0


def build_query_seeds(*, profile: str) -> list[str]:
    seeds: list[str] = []
    seeds.extend(list(string.ascii_lowercase))
    seeds.extend(list(string.digits))
    seeds.extend(ENGLISH_CATEGORY_SEEDS)
    seeds.extend(ENGLISH_DISTRICT_SEEDS)
    seeds.extend(ZH_DISTRICT_SEEDS)
    seeds.extend(CHINESE_SEEDS)
    for suffix in ["tower", "estate", "garden", "plaza", "hotel", "school", "mall", "house"]:
        for letter in string.ascii_lowercase:
            seeds.append(f"{letter} {suffix}")
    for suffix in ["花園", "苑", "邨", "廣場", "中心", "大廈", "酒店", "醫院", "學校"]:
        for prefix in ["中", "大", "新", "東", "西", "海", "山", "嘉", "華", "麗", "寶", "富", "美", "翠", "景"]:
            seeds.append(prefix + suffix)
    if profile == "phase2":
        seeds.extend(build_phase2_query_seeds())
    return dedupe_preserve_order(seeds)


def build_phase2_query_seeds() -> list[str]:
    seeds: list[str] = []
    for district in ENGLISH_DISTRICT_SEEDS:
        for suffix in PHASE2_ENGLISH_SUFFIXES:
            seeds.append(f"{district} {suffix}")
    for district in ZH_DISTRICT_SEEDS:
        for suffix in PHASE2_CHINESE_SUFFIXES:
            seeds.append(f"{district}{suffix}")
    for modifier in PHASE2_ENGLISH_MODIFIERS:
        for suffix in PHASE2_ENGLISH_SUFFIXES:
            seeds.append(f"{modifier} {suffix}")
    for prefix in PHASE2_CHINESE_PREFIXES:
        for suffix in PHASE2_CHINESE_SUFFIXES:
            seeds.append(f"{prefix}{suffix}")
    for district in ENGLISH_DISTRICT_SEEDS:
        for modifier in ["north", "south", "east", "west", "central", "new"]:
            seeds.append(f"{district} {modifier}")
    for district in ZH_DISTRICT_SEEDS:
        for suffix in ["中心", "大廈", "廣場", "花園", "苑", "邨", "酒店", "學校"]:
            for prefix in ["新", "東", "西", "南", "北", "海", "山"]:
                seeds.append(f"{district}{prefix}{suffix}")
    return seeds


def fetch_locations(query: str) -> list[dict]:
    params = urllib.parse.urlencode({"q": query})
    url = f"{API_BASE}?{params}"
    request = urllib.request.Request(url, headers=REQUEST_HEADERS)
    with urllib.request.urlopen(request, timeout=20) as response:
        payload = response.read().decode("utf-8")
    data = json.loads(payload)
    if not isinstance(data, list):
        return []
    return [item for item in data if isinstance(item, dict)]


def preferred_name(name_en: str, name_zh: str) -> str:
    zh = normalize_name(name_zh)
    en = normalize_name(name_en)
    if zh and has_han(zh):
        return zh
    return en or zh


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
    if has_han(keyword):
        return keyword in original_name
    return keyword.casefold() in lowered_name


def is_candidate_name(name: str) -> bool:
    normalized = normalize_name(name)
    if len(normalized) <= 1:
        return False
    lower = normalized.casefold()
    if any(token in lower for token in BAD_EN_SUBSTRINGS):
        return False
    if any(token in normalized for token in BAD_ZH_SUBSTRINGS):
        return False
    if normalized.isdigit():
        return False
    return True


def has_han(text: str) -> bool:
    return any("\u4e00" <= ch <= "\u9fff" for ch in text)


def normalize_name(value: str) -> str:
    return " ".join((value or "").split()).strip()


def load_existing_names() -> set[str]:
    names: set[str] = set()
    for subcategory in DIR_FILE_TO_SUBCATEGORY.values():
        path = Path(DEFAULT_OUTPUT_BY_SUBCATEGORY[subcategory])
        if not path.exists():
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, list):
            continue
        for item in data:
            if not isinstance(item, dict):
                continue
            for key in ("displayName", "nameEn", "nameZh"):
                normalized = normalize_name(str(item.get(key, ""))).casefold()
                if normalized:
                    names.add(normalized)
    return names


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


def write_batch_csv(path: Path, buckets: dict[str, list[str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_HEADERS)
        writer.writeheader()
        for filename, names in buckets.items():
            subcategory = DIR_FILE_TO_SUBCATEGORY[filename]
            for name in names:
                writer.writerow(
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
                        "limit": "1",
                        "enabled": "true",
                    }
                )


def build_summary(
    *,
    profile: str,
    seeds_processed: int,
    buckets: dict[str, list[str]],
    seed_progress: list[dict],
    targets: dict[str, int],
    skipped_existing: int,
) -> dict:
    counts = {}
    deficits = {}
    total = 0
    for filename, target in targets.items():
        actual = len(buckets[filename])
        counts[filename] = {
            "target": target,
            "actual": actual,
        }
        deficits[filename] = max(target - actual, 0)
        total += actual
    return {
        "profile": profile,
        "seedsProcessed": seeds_processed,
        "totalActual": total,
        "skippedExisting": skipped_existing,
        "counts": counts,
        "deficits": deficits,
        "seedProgress": seed_progress,
    }


if __name__ == "__main__":
    raise SystemExit(main())
