#!/usr/bin/env python3
import csv
import io
import json
import sys
import requests

CSV_URL = "https://resource.data.one.gov.hk/td/psiparkingspaces/spaceinfo/parkingspaces.csv"


def fetch_csv(url: str) -> str:
    res = requests.get(url, timeout=30)
    res.raise_for_status()
    return res.content.decode("utf-8-sig")


def main() -> int:
    text = fetch_csv(CSV_URL)
    lines = text.splitlines()

    # Find header line (CSV sometimes has two preamble lines)
    start = 0
    for i, line in enumerate(lines[:5]):
        if "ParkingSpaceId" in line:
            start = i
            break

    reader = csv.DictReader(io.StringIO("\n".join(lines[start:])))
    headers = reader.fieldnames or []

    rows = list(reader)
    out = {
        "fields": headers,
        "rows": rows,
    }

    out_path = "metered_parking_spaces.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"Wrote {len(rows)} rows to {out_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
