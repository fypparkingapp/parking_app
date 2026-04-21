#!/usr/bin/env python3
"""Train a LightGBM vacancy forecaster for metered street parking groups.

Each "group" is a set of meters on the same street section, sharing the same
VehicleType and OperatingPeriod.  The model predicts the number of vacant
spaces 60 minutes ahead (horizon_steps=12 × 5-min snapshots).

Features
--------
- Temporal:  hour_sin, hour_cos, dow_sin, dow_cos, is_weekend
- Lag:       lag_1 .. lag_12  (5-min snapshots)
- Rolling:   roll_mean_3, roll_mean_6, roll_std_3, roll_std_6
- Capacity:  total_spaces (static, from spaceinfo)
- Ratio:     vacancy_ratio = lag_1 / total_spaces
- Historical: group_hour_mean, group_dow_mean

Training strategy mirrors train_gov_vacancy_lgbm.py:
  - Walk-forward chronological split
  - Delta prediction: model learns (target − lag_1); lag_1 added back at inference

Examples
--------
  python3 scripts/train_gov_meter_vacancy_lgbm.py \\
    --data-root gov_meters \\
    --max-files 5000 \\
    --report-out tmp/meter_report_h12.json \\
    --model-out tmp/meter_model_h12.txt

  # Quick smoke test
  python3 scripts/train_gov_meter_vacancy_lgbm.py \\
    --data-root gov_meters \\
    --max-files 600 \\
    --report-out tmp/meter_report_smoke.json
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import io
import json
import math
import re
import sys
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path

import lightgbm as lgb
import numpy as np
import pandas as pd

TIMESTAMP_RE = re.compile(r"(\d{4}-\d{2}-\d{2} \d{2}-\d{2}-\d{2})")
MAX_LAG = 12


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="LightGBM meter vacancy forecaster.")
    p.add_argument("--data-root", required=True,
                   help="gov_meters root (contains resource.data.one.gov.hk/)")
    p.add_argument("--train-ratio", type=float, default=0.8)
    p.add_argument("--horizon-steps", type=int, default=12,
                   help="Forecast horizon in snapshots (5 min each). Default: 12 = 60 min")
    p.add_argument("--min-history", type=int, default=MAX_LAG)
    p.add_argument("--reset-gap-minutes", type=float, default=60.0,
                   help="Reset lag history after gaps larger than this. Default: 60")
    p.add_argument("--max-files", type=int, default=0)
    p.add_argument("--sample-every", type=int, default=1)
    p.add_argument("--min-group-spaces", type=int, default=3,
                   help="Ignore groups with fewer than this many spaces. Default: 3")
    p.add_argument("--top-groups", type=int, default=10)
    p.add_argument("--num-leaves", type=int, default=63)
    p.add_argument("--n-estimators", type=int, default=2000)
    p.add_argument("--early-stopping-rounds", type=int, default=80)
    p.add_argument("--learning-rate", type=float, default=0.05)
    p.add_argument("--report-out", default="")
    p.add_argument("--model-out", default="")
    p.add_argument("--verbose", action="store_true")
    return p


# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

@dataclass
class GroupBuffer:
    total_spaces: int
    values: deque[float] = field(default_factory=lambda: deque(maxlen=MAX_LAG))
    times: deque[dt.datetime] = field(default_factory=lambda: deque(maxlen=MAX_LAG))
    hour_sums: list[float] = field(default_factory=lambda: [0.0] * 24)
    hour_counts: list[int] = field(default_factory=lambda: [0] * 24)
    dow_sums: list[float] = field(default_factory=lambda: [0.0] * 7)
    dow_counts: list[int] = field(default_factory=lambda: [0] * 7)

    def reset(self) -> None:
        self.values.clear()
        self.times.clear()

    def push(self, ts: dt.datetime, v: float) -> None:
        self.values.append(v)
        self.times.append(ts)
        h, d = ts.hour, ts.weekday()
        self.hour_sums[h] += v
        self.hour_counts[h] += 1
        self.dow_sums[d] += v
        self.dow_counts[d] += 1

    def hour_mean(self, h: int) -> float:
        return self.hour_sums[h] / self.hour_counts[h] if self.hour_counts[h] else float("nan")

    def dow_mean(self, d: int) -> float:
        return self.dow_sums[d] / self.dow_counts[d] if self.dow_counts[d] else float("nan")


@dataclass
class PendingRow:
    split: str
    group_key: str
    features: dict[str, float]
    lag_1: float


# ---------------------------------------------------------------------------
# Feature builder
# ---------------------------------------------------------------------------

def make_features(ts: dt.datetime, buf: GroupBuffer) -> dict[str, float]:
    vals = list(buf.values)
    n = len(vals)
    h, d = ts.hour, ts.weekday()
    feats: dict[str, float] = {}

    feats["hour_sin"] = math.sin(2 * math.pi * h / 24)
    feats["hour_cos"] = math.cos(2 * math.pi * h / 24)
    feats["dow_sin"] = math.sin(2 * math.pi * d / 7)
    feats["dow_cos"] = math.cos(2 * math.pi * d / 7)
    feats["is_weekend"] = float(d >= 5)

    for i in range(1, MAX_LAG + 1):
        feats[f"lag_{i}"] = vals[-i] if n >= i else float("nan")

    w3 = vals[-3:] if n >= 3 else vals
    w6 = vals[-6:] if n >= 6 else vals
    feats["roll_mean_3"] = float(np.mean(w3)) if w3 else float("nan")
    feats["roll_mean_6"] = float(np.mean(w6)) if w6 else float("nan")
    feats["roll_std_3"] = float(np.std(w3)) if len(w3) > 1 else 0.0
    feats["roll_std_6"] = float(np.std(w6)) if len(w6) > 1 else 0.0

    feats["group_hour_mean"] = buf.hour_mean(h)
    feats["group_dow_mean"] = buf.dow_mean(d)

    cap = float(buf.total_spaces)
    feats["total_spaces"] = cap
    lag1 = vals[-1] if n >= 1 else float("nan")
    feats["vacancy_ratio"] = lag1 / cap if (n >= 1 and cap > 0) else float("nan")

    return feats


# ---------------------------------------------------------------------------
# File discovery & parsing
# ---------------------------------------------------------------------------

def resolve_meter_root(path: Path) -> Path:
    path = path.expanduser().resolve()
    candidate = path / "resource.data.one.gov.hk"
    if candidate.exists():
        return candidate
    if path.name == "resource.data.one.gov.hk":
        return path
    raise RuntimeError(f"Cannot find resource.data.one.gov.hk under {path}")


def discover_occupancy_snapshots(root: Path, *, sample_every: int, max_files: int) -> list[Path]:
    files = sorted((root / "td-psiparkingspaces-occupancystatus").glob("*/*/*/*.csv"))
    if sample_every > 1:
        files = files[::sample_every]
    if max_files > 0:
        files = files[:max_files]
    return files


def parse_ts(path: Path) -> dt.datetime:
    m = TIMESTAMP_RE.search(path.name)
    if not m:
        raise RuntimeError(f"Cannot parse timestamp from {path.name}")
    return dt.datetime.strptime(m.group(1), "%Y-%m-%d %H-%M-%S")


def load_spaceinfo(root: Path, min_group_spaces: int) -> tuple[dict[str, str], dict[str, int]]:
    """Return (space_id → group_key, group_key → total_spaces) from the latest spaceinfo CSV."""
    spaceinfo_files = sorted((root / "td-psiparkingspaces-spaceinfo").glob("*/*/*/*.csv"))
    if not spaceinfo_files:
        raise RuntimeError(f"No spaceinfo CSVs found under {root}")

    latest = spaceinfo_files[-1]
    raw_lines = latest.read_text(encoding="utf-8-sig").splitlines()
    # First two lines: date header + blank/comma line
    data_lines = raw_lines[2:]
    reader = csv.DictReader(data_lines)

    space_to_group: dict[str, str] = {}
    group_counts: dict[str, int] = {}

    for row in reader:
        space_id = row.get("ParkingSpaceId", "").strip()
        if not space_id:
            continue
        key = _group_key(row)
        space_to_group[space_id] = key
        group_counts[key] = group_counts.get(key, 0) + 1

    # Filter out tiny groups
    valid_groups = {k for k, v in group_counts.items() if v >= min_group_spaces}
    space_to_group = {s: g for s, g in space_to_group.items() if g in valid_groups}
    group_totals = {k: v for k, v in group_counts.items() if k in valid_groups}

    return space_to_group, group_totals


def _group_key(row: dict[str, str]) -> str:
    vt = row.get("VehicleType", "").strip()
    op = row.get("OperatingPeriod", "").strip()
    district = row.get("District", "").strip()
    street = row.get("Street", "").strip()
    section = row.get("SectionOfStreet", "").strip() or "-"
    return f"{vt}|{op}|{district}|{street}|{section}"


def read_occupancy_snapshot(path: Path) -> dict[str, str]:
    """Return {ParkingSpaceId: OccupancyStatus} for one snapshot."""
    reader = csv.DictReader(path.read_text(encoding="utf-8-sig").splitlines())
    return {
        row["ParkingSpaceId"]: row.get("OccupancyStatus", "")
        for row in reader
        if row.get("ParkingSpaceId")
    }


def aggregate_vacancies(
    occupancy: dict[str, str],
    space_to_group: dict[str, str],
) -> dict[str, int]:
    """Count vacant (V) spaces per group."""
    counts: dict[str, int] = {}
    for space_id, status in occupancy.items():
        group = space_to_group.get(space_id)
        if group is None:
            continue
        if status == "V":
            counts[group] = counts.get(group, 0) + 1
    return counts


# ---------------------------------------------------------------------------
# Main training pipeline
# ---------------------------------------------------------------------------

def run_training(args: argparse.Namespace) -> dict:
    root = resolve_meter_root(Path(args.data_root))

    if args.verbose:
        print("[meter] Loading spaceinfo...", file=sys.stderr)
    space_to_group, group_totals = load_spaceinfo(root, args.min_group_spaces)
    if args.verbose:
        print(f"[meter] {len(group_totals)} groups, {len(space_to_group)} spaces", file=sys.stderr)

    snapshots = discover_occupancy_snapshots(
        root, sample_every=args.sample_every, max_files=args.max_files,
    )
    if not snapshots:
        raise RuntimeError(f"No occupancy snapshots found under {root}")

    train_cutoff = len(snapshots)
    if args.train_ratio < 1:
        train_cutoff = max(1, min(len(snapshots) - 1, int(len(snapshots) * args.train_ratio)))

    buffers: dict[str, GroupBuffer] = {
        key: GroupBuffer(total_spaces=total)
        for key, total in group_totals.items()
    }
    pending: dict[str, deque[PendingRow]] = {key: deque() for key in group_totals}

    rows_train: list[dict] = []
    rows_test: list[dict] = []
    targets_train: list[float] = []
    targets_test: list[float] = []

    processed = 0
    first_ts = last_ts = None

    for idx, snap_path in enumerate(snapshots):
        split = "train" if idx < train_cutoff else "test"
        ts = parse_ts(snap_path)
        first_ts = first_ts or ts
        last_ts = ts

        if args.verbose and idx % 500 == 0:
            print(f"[{idx+1}/{len(snapshots)}] split={split} {snap_path.name}", file=sys.stderr)

        occupancy = read_occupancy_snapshot(snap_path)
        vacancies = aggregate_vacancies(occupancy, space_to_group)

        for group_key, buf in buffers.items():
            value = float(vacancies.get(group_key, 0))
            pq = pending[group_key]

            # Gap reset
            if buf.times and (ts - buf.times[-1]).total_seconds() / 60 > args.reset_gap_minutes:
                buf.reset()
                pq.clear()

            # Resolve pending example at horizon
            if len(pq) >= args.horizon_steps:
                ready: PendingRow = pq.popleft()
                delta_target = value - ready.lag_1
                ready.features["_group_key"] = ready.group_key
                if ready.split == "train":
                    rows_train.append(ready.features)
                    targets_train.append(delta_target)
                else:
                    rows_test.append(ready.features)
                    targets_test.append(delta_target)

            # Emit new pending example if enough history
            if len(buf.values) >= args.min_history:
                feats = make_features(ts, buf)
                pq.append(PendingRow(
                    split=split,
                    group_key=group_key,
                    features=feats,
                    lag_1=buf.values[-1],
                ))

            buf.push(ts, value)
            processed += 1

    if not rows_train:
        raise RuntimeError("No training examples — try reducing --min-history or --max-files")

    # -----------------------------------------------------------------------
    # Build DataFrames
    # -----------------------------------------------------------------------
    feature_cols = [c for c in rows_train[0].keys() if c != "_group_key"]

    df_train = pd.DataFrame(rows_train)[feature_cols]
    df_test = pd.DataFrame(rows_test)[feature_cols] if rows_test else pd.DataFrame(columns=feature_cols)
    y_train = np.array(targets_train, dtype=np.float32)
    y_test = np.array(targets_test, dtype=np.float32) if targets_test else np.array([], dtype=np.float32)

    # Lag_1 arrays for baseline (in absolute vacancy, not delta)
    lag1_train = df_train["lag_1"].values
    # actual absolute vacancy = lag_1 + delta_target
    actual_train = lag1_train + y_train

    if args.verbose:
        print(f"[build] train={len(df_train)} test={len(df_test)} features={len(feature_cols)}", file=sys.stderr)

    # -----------------------------------------------------------------------
    # Train LightGBM  (delta mode: target = actual − lag_1)
    # -----------------------------------------------------------------------
    params = {
        "objective": "regression_l1",
        "metric": "mae",
        "num_leaves": args.num_leaves,
        "learning_rate": args.learning_rate,
        "n_estimators": args.n_estimators,
        "min_child_samples": 20,
        "subsample": 0.8,
        "colsample_bytree": 0.8,
        "verbose": -1,
    }

    callbacks = []
    if args.verbose:
        callbacks.append(lgb.log_evaluation(period=100))

    eval_set = [(df_test, y_test)] if len(df_test) > 0 else None
    if eval_set is not None:
        callbacks.append(lgb.early_stopping(stopping_rounds=args.early_stopping_rounds, verbose=args.verbose))

    model = lgb.LGBMRegressor(**params)
    model.fit(df_train, y_train, eval_set=eval_set, callbacks=callbacks)

    best_iteration = getattr(model, "best_iteration_", args.n_estimators)
    if args.verbose:
        print(f"[lgbm] best_iteration={best_iteration}", file=sys.stderr)

    # -----------------------------------------------------------------------
    # Evaluate (reconstruct absolute vacancy from delta predictions)
    # -----------------------------------------------------------------------
    def metrics(pred: np.ndarray, actual: np.ndarray) -> dict:
        if len(actual) == 0:
            return {"count": 0, "mae": None, "rmse": None}
        err = pred - actual
        return {
            "count": int(len(actual)),
            "mae": float(np.mean(np.abs(err))),
            "rmse": float(np.sqrt(np.mean(err ** 2))),
        }

    raw_pred_train = model.predict(df_train)
    pred_train = np.maximum(0, lag1_train + raw_pred_train)
    result_metrics: dict = {
        "train": {
            "model": metrics(pred_train, actual_train),
            "lag_1_baseline": metrics(lag1_train, actual_train),
        }
    }

    top_groups: list[dict] = []
    if len(df_test) > 0:
        lag1_test = df_test["lag_1"].values
        actual_test = lag1_test + y_test
        raw_pred_test = model.predict(df_test)
        pred_test = np.maximum(0, lag1_test + raw_pred_test)
        result_metrics["test"] = {
            "model": metrics(pred_test, actual_test),
            "lag_1_baseline": metrics(lag1_test, actual_test),
        }

        # Per-group metrics
        group_buckets: dict[str, dict] = {}
        for r, pv, av, l1v in zip(rows_test, pred_test, actual_test, lag1_test):
            gk = r.get("_group_key", "unknown")
            b = group_buckets.setdefault(gk, {"pred": [], "actual": [], "lag1": []})
            b["pred"].append(pv)
            b["actual"].append(av)
            b["lag1"].append(l1v)

        for gk, b in group_buckets.items():
            pa = np.array(b["pred"])
            aa = np.array(b["actual"])
            la = np.array(b["lag1"])
            mm = metrics(pa, aa)
            lm = metrics(la, aa)
            gain = (lm["mae"] - mm["mae"]) if (mm["mae"] and lm["mae"]) else None
            top_groups.append({"group_key": gk, "model": mm, "lag_1_baseline": lm, "mae_gain": gain})

        top_groups.sort(key=lambda x: -(x["model"]["count"] or 0))
        top_groups = top_groups[:args.top_groups]

    importance = dict(zip(feature_cols, model.feature_importances_.tolist()))
    top_features = sorted(importance.items(), key=lambda x: -x[1])[:15]

    report = {
        "config": {
            "data_root": str(root),
            "horizon_steps": args.horizon_steps,
            "horizon_minutes": args.horizon_steps * 5,
            "train_ratio": args.train_ratio,
            "max_files": args.max_files or None,
            "min_group_spaces": args.min_group_spaces,
            "n_estimators_max": args.n_estimators,
            "best_iteration": best_iteration,
            "early_stopping_rounds": args.early_stopping_rounds,
            "num_leaves": args.num_leaves,
            "learning_rate": args.learning_rate,
        },
        "data_summary": {
            "snapshot_count": len(snapshots),
            "train_snapshots": train_cutoff,
            "test_snapshots": len(snapshots) - train_cutoff,
            "first_snapshot": first_ts.isoformat() if first_ts else None,
            "last_snapshot": last_ts.isoformat() if last_ts else None,
            "group_count": len(group_totals),
            "train_examples": len(rows_train),
            "test_examples": len(rows_test),
        },
        "metrics": result_metrics,
        "top_features": [{"name": n, "importance": v} for n, v in top_features],
        "top_groups": top_groups,
    }

    if args.report_out:
        _write_json(Path(args.report_out), report)
    if args.model_out:
        mp = Path(args.model_out).expanduser().resolve()
        mp.parent.mkdir(parents=True, exist_ok=True)
        model.booster_.save_model(str(mp))
        if args.verbose:
            print(f"[saved] model -> {mp}", file=sys.stderr)

    return report


# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

def print_summary(report: dict) -> None:
    ds = report["data_summary"]
    m = report["metrics"]
    cfg = report["config"]
    print("LightGBM meter vacancy training summary")
    print(f"- Snapshots: {ds['snapshot_count']}  (train {ds['train_snapshots']} / test {ds['test_snapshots']})")
    print(f"- Range:     {ds['first_snapshot']} -> {ds['last_snapshot']}")
    print(f"- Groups:    {ds['group_count']}  examples: train {ds['train_examples']} / test {ds['test_examples']}")
    print(f"- Horizon:   {cfg['horizon_steps']} steps = {cfg['horizon_minutes']} min")
    print(f"- Best iter: {cfg['best_iteration']}")
    for split in ("train", "test"):
        if split not in m:
            continue
        mm, bl = m[split]["model"], m[split]["lag_1_baseline"]
        gain = ""
        if mm["mae"] and bl["mae"]:
            gain = f"  (gain vs lag_1: {bl['mae'] - mm['mae']:+.4f})"
        print(f"- {split} model  MAE {_fmt(mm['mae'])}  RMSE {_fmt(mm['rmse'])}  n={mm['count']}{gain}")
        print(f"- {split} lag_1  MAE {_fmt(bl['mae'])}  RMSE {_fmt(bl['rmse'])}")
    print("- Top features:")
    for item in report["top_features"][:10]:
        print(f"  {item['name']:25s}  {item['importance']}")


def _fmt(v: object) -> str:
    return f"{v:.4f}" if isinstance(v, float) else "n/a"


def _write_json(path: Path, payload: object) -> None:
    path = path.expanduser().resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> int:
    args = build_parser().parse_args()
    try:
        report = run_training(args)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    print_summary(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
