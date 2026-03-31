# link_parking_scan.py (robust CSV writing + clear path + verbose option)
# Python 3.x — standard library only
import sys, json, re, time, argparse, os
from pathlib import Path
from urllib import request, error

BASE = "https://apim-gateway-prd.azure.linkreit.com/MPCMS/PRD2"

def http_get_text(url: str, verbose: bool=False) -> str:
    if verbose:
        print(f"[GET] {url}")
    req = request.Request(url, headers={
        "Accept": "application/json",
        "User-Agent": "python/link-parking-scan"
    })
    try:
        with request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            if verbose:
                print(f"[GET] {url} -> {resp.status}")
            if resp.status >= 400:
                raise RuntimeError(f"HTTP {resp.status} {url}: {body[:200]}")
            return body
    except error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code} for {url}: {body[:200]}") from None
    except Exception as e:
        raise RuntimeError(f"Request failed for {url}: {e}") from None

def extract_facility_keys(listing_text: str):
    keys = set()
    try:
        obj = json.loads(listing_text)
        def walk(o):
            if isinstance(o, dict):
                for k, v in o.items():
                    if k == "facilityKey":
                        try: keys.add(int(v))
                        except: pass
                    walk(v)
            elif isinstance(o, list):
                for it in o: walk(it)
        walk(obj)
    except Exception:
        pass
    if not keys:
        for m in re.finditer(r'"facilityKey"\s*:\s*(\d+)', listing_text):
            keys.add(int(m.group(1)))
    return sorted(keys)

def strip_tags(s: str) -> str:
    return re.sub(r"<[^>]+>", "", s or "").trim() if hasattr(str, "trim") else re.sub(r"<[^>]+>", "", s or "").strip()

SECTION_RE = re.compile(
    r"<h4[^>]*>(.*?)</h4>([\s\S]*?)(?=<h4|</ul>|</div>)",
    re.IGNORECASE
)

def main():
    ap = argparse.ArgumentParser(description="Scan Link REIT parking rates.")
    ap.add_argument("--csv", action="store_true", help="Write CSV")
    ap.add_argument("--out", default="link_parking_prices.csv", help="Output CSV path (with --csv)")
    ap.add_argument("--limit", type=int, default=None, help="Process only first N facilities")
    ap.add_argument("--only-en", action="store_true", help="Use only allRateHtmlEn")
    ap.add_argument("--allow-no-dollar", action="store_true",
                    help="Also capture numbers without a '$' prefix")
    ap.add_argument("--verbose", action="store_true", help="Verbose logging")
    args = ap.parse_args()

    if args.verbose:
        print(f"[cwd] {Path.cwd().resolve()}")
        print(f"[opts] csv={args.csv}, out={args.out}, limit={args.limit}, only_en={args.only_en}, allow_no_dollar={args.allow_no_dollar}")

    # Prepare CSV path early so we can always write something
    out_path = Path(args.out).expanduser().resolve()

    # 1) Listing
    keys = []
    try:
        print("Fetching facility list…")
        listing_text = http_get_text(f"{BASE}/parking?pageSize=175", verbose=args.verbose)
        keys = extract_facility_keys(listing_text)
        if args.limit is not None and args.limit < len(keys):
            keys = keys[:args.limit]
            print(f"Limiting to first {len(keys)} facilities for testing.")
        print(f"Found {len(keys)} facilities.")
    except Exception as e:
        print(f"! Could not fetch list ({e}). Will still write CSV header if --csv was given.", file=sys.stderr)

    labels = set()
    prices = []  # tuples: (facilityKey, name, label, amount)
    processed = 0

    # 2) Per-facility fetch (only if we have keys)
    amt_re_str = r"\$\s*([0-9]+(?:\.[0-9]{1,2})?)" if not args.allow_no_dollar else r"\$?\s*([0-9]+(?:\.[0-9]{1,2})?)"
    amt_re = re.compile(amt_re_str)

    for key in keys:
        processed += 1
        if processed % 20 == 0:
            time.sleep(0.4)

        url = f"{BASE}/parking/{key}?parkingInfo"
        try:
            txt = http_get_text(url, verbose=args.verbose)
            j = json.loads(txt)
            info = j.get("data", {}).get("parkingInfo")
            if not info:
                continue

            name = str(info.get("carParkFacilityNameEn", key))
            html = (info.get("allRateHtmlEn") or "") if args.only_en else \
                   (info.get("allRateHtmlEn") or info.get("allRateHtmlTc") or info.get("allRateHtmlSc") or "")
            if not html:
                continue

            for sec in SECTION_RE.finditer(html):
                raw_label = sec.group(1) or ""
                label = re.sub(r"<[^>]+>", "", raw_label).strip()
                if not label:
                    continue
                labels.add(label)

                body = sec.group(2) or ""
                for m in amt_re.finditer(body):
                    try:
                        amount = float(m.group(1))
                        prices.append((key, name, label, amount))
                    except:
                        pass

        except Exception as e:
            if args.verbose:
                print(f"! Failed on facility {key}: {e}", file=sys.stderr)

    # 3) Print summaries
    print("\nDistinct price labels found:")
    for l in sorted(labels):
        print(f" - {l}")

    if prices:
        all_amts = sorted(p[3] for p in prices)
        print(f"\nObserved amount range across all car parks: min ${all_amts[0]} / max ${all_amts[-1]}")
    else:
        print("\nNo amounts parsed.")

    # Per-label ranges
    by_label = {}
    for key, name, label, amt in prices:
        by_label.setdefault(label, []).append(amt)
    print("\nPer-label ranges:")
    for label, arr in sorted(by_label.items()):
        arr.sort()
        print(f" - {label}: min ${arr[0]} / max ${arr[-1]}")

    # 4) CSV writing (always writes header if --csv)
    if args.csv:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w", encoding="utf-8", newline="") as f:
            f.write("facilityKey,name,label,amount\n")
            for key, name, label, amt in prices:
                def esc(s: str) -> str:
                    return '"' + s.replace('"', '""') + '"' if ("," in s or '"' in s) else s
                f.write(f"{key},{esc(name)},{esc(label)},{amt}\n")
        print(f"\nSaved CSV: {out_path}")

if __name__ == "__main__":
    main()
