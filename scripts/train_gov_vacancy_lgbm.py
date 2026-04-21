#!/usr/bin/env python3
"""Train a LightGBM vacancy forecaster from mirrored gov_vacancy data.

Features
--------
- Temporal:  hour_sin, hour_cos, dow_sin, dow_cos, is_weekend
- Lag:       lag_1 .. lag_6  (observed snapshots, ~10 min each)
- Rolling:   roll_mean_3, roll_mean_6, roll_std_3, roll_std_6
- Capacity:  park_capacity (max observed vacancy per park, used as proxy)
- Ratio:     lag_1 / park_capacity  (occupancy proxy)

Evaluation
----------
Walk-forward chronological split (train_ratio controls the cut).
Reports MAE / RMSE vs lag_1 baseline, both overall and per-park.

Examples
--------
  python3 scripts/train_gov_vacancy_lgbm.py \\
    --data-root gov_vacancy \\
    --max-files 5000 --horizon-steps 6 \\
    --report-out tmp/lgbm_report_h6.json \\
    --model-out tmp/lgbm_model_h6.txt

  # Quick smoke test
  python3 scripts/train_gov_vacancy_lgbm.py \\
    --data-root gov_vacancy \\
    --max-files 600 \\
    --report-out tmp/lgbm_report_smoke.json
"""

from __future__ import annotations

import argparse
import datetime as dt
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
MAX_LAG = 6


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="LightGBM vacancy forecaster.")
    p.add_argument("--data-root", required=True,
                   help="gov_vacancy root or path to v1-carpark-info-vacancy/")
    p.add_argument("--vehicle-type", default="privateCar")
    p.add_argument("--target-key", default="vacancy")
    p.add_argument("--train-ratio", type=float, default=0.8)
    p.add_argument("--horizon-steps", type=int, default=6,
                   help="Forecast horizon in snapshots (~10 min each). Default: 6 (~1 hr)")
    p.add_argument("--min-history", type=int, default=MAX_LAG,
                   help=f"Min snapshots before emitting an example. Default: {MAX_LAG}")
    p.add_argument("--reset-gap-minutes", type=float, default=180.0)
    p.add_argument("--max-files", type=int, default=0)
    p.add_argument("--sample-every", type=int, default=1)
    p.add_argument("--park-id", action="append", default=[])
    p.add_argument("--top-parks", type=int, default=10)
    p.add_argument("--num-leaves", type=int, default=63)
    p.add_argument("--n-estimators", type=int, default=800,
                   help="Max trees. Early stopping will halt earlier if val MAE stops improving.")
    p.add_argument("--early-stopping-rounds", type=int, default=50,
                   help="Stop if val MAE has not improved for this many rounds. Default: 50")
    p.add_argument("--learning-rate-lgbm", type=float, default=0.05)
    p.add_argument("--predict-delta", action="store_true",
                   help=(
                       "Train the model to predict (target - lag_1) instead of "
                       "absolute vacancy. At inference, lag_1 is added back. "
                       "This lets the model focus on correcting the lag_1 baseline."
                   ))
    p.add_argument("--report-out", default="")
    p.add_argument("--model-out", default="",
                   help="Path to save the LightGBM model (.txt)")
    p.add_argument("--verbose", action="store_true")
    return p


# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

@dataclass
class ParkBuffer:
    values: deque[float] = field(default_factory=lambda: deque(maxlen=MAX_LAG))
    times: deque[dt.datetime] = field(default_factory=lambda: deque(maxlen=MAX_LAG))
    hour_sums: list[float] = field(default_factory=lambda: [0.0] * 24)
    hour_counts: list[int] = field(default_factory=lambda: [0] * 24)
    dow_sums: list[float] = field(default_factory=lambda: [0.0] * 7)
    dow_counts: list[int] = field(default_factory=lambda: [0] * 7)
    max_observed: float = 0.0

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
        if v > self.max_observed:
            self.max_observed = v

    def hour_mean(self, h: int) -> float:
        return self.hour_sums[h] / self.hour_counts[h] if self.hour_counts[h] else float("nan")

    def dow_mean(self, d: int) -> float:
        return self.dow_sums[d] / self.dow_counts[d] if self.dow_counts[d] else float("nan")


# ---------------------------------------------------------------------------
# Feature builder
# ---------------------------------------------------------------------------

def make_features(ts: dt.datetime, buf: ParkBuffer) -> dict[str, float]:
    vals = list(buf.values)
    n = len(vals)
    h, d = ts.hour, ts.weekday()

    feats: dict[str, float] = {}

    # Temporal cyclical encoding
    feats["hour_sin"] = math.sin(2 * math.pi * h / 24)
    feats["hour_cos"] = math.cos(2 * math.pi * h / 24)
    feats["dow_sin"] = math.sin(2 * math.pi * d / 7)
    feats["dow_cos"] = math.cos(2 * math.pi * d / 7)
    feats["is_weekend"] = float(d >= 5)

    # Lag features (lag_1 = most recent, lag_6 = oldest in window)
    for i in range(1, MAX_LAG + 1):
        feats[f"lag_{i}"] = vals[-i] if n >= i else float("nan")

    # Rolling stats
    w3 = vals[-3:] if n >= 3 else vals
    w6 = vals[-6:] if n >= 6 else vals
    feats["roll_mean_3"] = float(np.mean(w3))
    feats["roll_mean_6"] = float(np.mean(w6))
    feats["roll_std_3"] = float(np.std(w3)) if len(w3) > 1 else 0.0
    feats["roll_std_6"] = float(np.std(w6)) if len(w6) > 1 else 0.0

    # Park-level historical means
    feats["park_hour_mean"] = buf.hour_mean(h)
    feats["park_dow_mean"] = buf.dow_mean(d)

    # Capacity proxy & occupancy ratio
    cap = buf.max_observed if buf.max_observed > 0 else float("nan")
    feats["park_capacity"] = cap
    feats["occupancy_ratio"] = vals[-1] / cap if (n >= 1 and not math.isnan(cap) and cap > 0) else float("nan")

    return feats


# ---------------------------------------------------------------------------
# Snapshot parsing (reused from baseline script)
# ---------------------------------------------------------------------------

def resolve_data_root(path: Path) -> Path:
    path = path.expanduser().resolve()
    vacancy_dir = path / "api.data.gov.hk" / "v1-carpark-info-vacancy"
    if vacancy_dir.exists():
        return vacancy_dir
    if path.name == "v1-carpark-info-vacancy":
        return path
    raise RuntimeError(
        f"Expected gov_vacancy root or v1-carpark-info-vacancy dir, got: {path}"
    )


def discover_snapshots(root: Path, *, sample_every: int, max_files: int) -> list[Path]:
    files = sorted(root.glob("*/*/*/*.json"))
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


def extract_value(raw_vehicle: object, target_key: str) -> float | None:
    if not isinstance(raw_vehicle, list) or not raw_vehicle:
        return None
    total, found = 0.0, False
    for item in raw_vehicle:
        if not isinstance(item, dict):
            continue
        v = item.get(target_key)
        if isinstance(v, (int, float)):
            total += float(v)
            found = True
    return total if found else None


# ---------------------------------------------------------------------------
# Main training pipeline
# ---------------------------------------------------------------------------

@dataclass
class PendingRow:
    split: str
    features: dict[str, float]
    lag_1: float
    park_id: str


def run_training(args: argparse.Namespace) -> dict:
    root = resolve_data_root(Path(args.data_root))
    snapshots = discover_snapshots(root, sample_every=args.sample_every, max_files=args.max_files)
    if not snapshots:
        raise RuntimeError(f"No snapshots found under {root}")

    train_cutoff = len(snapshots)
    if args.train_ratio < 1:
        train_cutoff = max(1, min(len(snapshots) - 1, int(len(snapshots) * args.train_ratio)))

    park_filter = set(args.park_id)
    buffers: dict[str, ParkBuffer] = {}
    pending: dict[str, deque[PendingRow]] = {}

    rows_train: list[dict] = []
    rows_test: list[dict] = []
    targets_train: list[float] = []
    targets_test: list[float] = []

    processed = skipped = 0
    first_ts = last_ts = None

    for idx, snap_path in enumerate(snapshots):
        split = "train" if idx < train_cutoff else "test"
        ts = parse_ts(snap_path)
        first_ts = first_ts or ts
        last_ts = ts

        if args.verbose and idx % 500 == 0:
            print(f"[{idx+1}/{len(snapshots)}] split={split} {snap_path.name}", file=sys.stderr)

        payload = json.loads(snap_path.read_text(encoding="utf-8"))
        results = payload.get("results", [])
        if not isinstance(results, list):
            continue

        for row in results:
            if not isinstance(row, dict):
                continue
            park_id = str(row.get("park_Id", "")).strip()
            if not park_id:
                skipped += 1
                continue
            if park_filter and park_id not in park_filter:
                continue

            value = extract_value(row.get(args.vehicle_type), args.target_key)
            if value is None:
                skipped += 1
                continue

            buf = buffers.setdefault(park_id, ParkBuffer())
            pq = pending.setdefault(park_id, deque())

            # Gap reset
            if buf.times and (ts - buf.times[-1]).total_seconds() / 60 > args.reset_gap_minutes:
                buf.reset()
                pq.clear()

            # Resolve pending example that is now horizon_steps in the past
            if len(pq) >= args.horizon_steps:
                ready: PendingRow = pq.popleft()
                # In delta mode the model learns (actual - lag_1); lag_1 is added back at inference.
                train_target = (value - ready.lag_1) if args.predict_delta else value
                ready.features["target"] = value  # always store absolute for reference
                if ready.split == "train":
                    rows_train.append(ready.features)
                    targets_train.append(train_target)
                else:
                    rows_test.append(ready.features)
                    targets_test.append(train_target)

            # Emit new pending example if enough history
            if len(buf.values) >= args.min_history:
                feats = make_features(ts, buf)
                feats["_park_id"] = park_id  # kept for per-park eval, excluded from model features
                pq.append(PendingRow(split=split, features=feats, lag_1=buf.values[-1], park_id=park_id))

            buf.push(ts, value)
            processed += 1

    if not rows_train:
        raise RuntimeError("No training examples built — check --min-history / --max-files")

    # -----------------------------------------------------------------------
    # Build DataFrames
    # -----------------------------------------------------------------------
    feature_cols = [c for c in rows_train[0].keys() if c not in ("target", "_park_id")]

    df_train = pd.DataFrame(rows_train)[feature_cols]
    df_test = pd.DataFrame(rows_test)[feature_cols] if rows_test else pd.DataFrame(columns=feature_cols)

    y_train = np.array(targets_train, dtype=np.float32)
    y_test = np.array(targets_test, dtype=np.float32) if targets_test else np.array([], dtype=np.float32)

    if args.verbose:
        print(f"[build] train={len(df_train)} test={len(df_test)} features={len(feature_cols)}", file=sys.stderr)

    # -----------------------------------------------------------------------
    # Train LightGBM
    # -----------------------------------------------------------------------
    params = {
        "objective": "regression_l1",   # MAE loss
        "metric": "mae",
        "num_leaves": args.num_leaves,
        "learning_rate": args.learning_rate_lgbm,
        "n_estimators": args.n_estimators,
        "min_child_samples": 20,
        "subsample": 0.8,
        "colsample_bytree": 0.8,
        "verbose": -1,
    }

    callbacks = []
    if args.verbose:
        callbacks.append(lgb.log_evaluation(period=50))

    eval_set = [(df_test, y_test)] if len(df_test) > 0 else None

    if eval_set is not None:
        callbacks.append(lgb.early_stopping(stopping_rounds=args.early_stopping_rounds, verbose=args.verbose))

    model = lgb.LGBMRegressor(**params)
    model.fit(
        df_train, y_train,
        eval_set=eval_set,
        callbacks=callbacks,
    )

    best_iteration = getattr(model, "best_iteration_", args.n_estimators)
    if args.verbose:
        print(f"[lgbm] best_iteration={best_iteration}", file=sys.stderr)

    # -----------------------------------------------------------------------
    # Evaluate
    # -----------------------------------------------------------------------
    def metrics(pred: np.ndarray, actual: np.ndarray) -> dict:
        if len(actual) == 0:
            return {"count": 0, "mae": None, "rmse": None}
        err = pred - actual
        mae = float(np.mean(np.abs(err)))
        rmse = float(np.sqrt(np.mean(err ** 2)))
        return {"count": int(len(actual)), "mae": mae, "rmse": rmse}

    lag1_train = df_train["lag_1"].values
    raw_pred_train = model.predict(df_train)
    # In delta mode: absolute prediction = lag_1 + delta; baseline target = 0 delta.
    if args.predict_delta:
        pred_train = np.maximum(0, lag1_train + raw_pred_train)
        actual_train = lag1_train + y_train          # back to absolute vacancy
    else:
        pred_train = np.maximum(0, raw_pred_train)
        actual_train = y_train

    result_metrics: dict = {
        "train": {
            "model": metrics(pred_train, actual_train),
            "lag_1_baseline": metrics(lag1_train, actual_train),
        }
    }

    if len(df_test) > 0:
        lag1_test = df_test["lag_1"].values
        raw_pred_test = model.predict(df_test)
        if args.predict_delta:
            pred_test = np.maximum(0, lag1_test + raw_pred_test)
            actual_test = lag1_test + y_test
        else:
            pred_test = np.maximum(0, raw_pred_test)
            actual_test = y_test
        result_metrics["test"] = {
            "model": metrics(pred_test, actual_test),
            "lag_1_baseline": metrics(lag1_test, actual_test),
        }

    # Feature importance
    importance = dict(zip(feature_cols, model.feature_importances_.tolist()))
    top_features = sorted(importance.items(), key=lambda x: -x[1])[:15]

    # Per-park metrics on test set
    top_parks: list[dict] = []
    if len(df_test) > 0:
        park_groups: dict[str, dict] = {}
        for r, pred_v, actual_v, lag1_v in zip(
            rows_test, pred_test, actual_test, lag1_test
        ):
            pid = r.get("_park_id", "unknown")
            g = park_groups.setdefault(pid, {"pred": [], "actual": [], "lag1": []})
            g["pred"].append(pred_v)
            g["actual"].append(actual_v)
            g["lag1"].append(lag1_v)

        for pid, g in park_groups.items():
            pred_arr = np.array(g["pred"])
            actual_arr = np.array(g["actual"])
            lag1_arr = np.array(g["lag1"])
            model_m = metrics(pred_arr, actual_arr)
            lag1_m = metrics(lag1_arr, actual_arr)
            gain = (lag1_m["mae"] - model_m["mae"]) if (lag1_m["mae"] is not None and model_m["mae"] is not None) else None
            top_parks.append({"park_id": pid, "model": model_m, "lag_1_baseline": lag1_m, "mae_gain": gain})

        top_parks.sort(key=lambda x: -(x["model"]["count"] or 0))
        top_parks = top_parks[:args.top_parks]

    report = {
        "config": {
            "data_root": str(root),
            "vehicle_type": args.vehicle_type,
            "target_key": args.target_key,
            "horizon_steps": args.horizon_steps,
            "train_ratio": args.train_ratio,
            "max_files": args.max_files or None,
            "park_filter": sorted(park_filter),
            "n_estimators_max": args.n_estimators,
            "best_iteration": best_iteration,
            "early_stopping_rounds": args.early_stopping_rounds,
            "num_leaves": args.num_leaves,
            "learning_rate_lgbm": args.learning_rate_lgbm,
            "predict_delta": args.predict_delta,
        },
        "data_summary": {
            "snapshot_count": len(snapshots),
            "train_snapshots": train_cutoff,
            "test_snapshots": len(snapshots) - train_cutoff,
            "first_snapshot": first_ts.isoformat() if first_ts else None,
            "last_snapshot": last_ts.isoformat() if last_ts else None,
            "train_examples": len(rows_train),
            "test_examples": len(rows_test),
            "park_count": len(buffers),
        },
        "metrics": result_metrics,
        "top_features": [{"name": n, "importance": v} for n, v in top_features],
        "top_parks": top_parks,
    }

    if args.report_out:
        _write_json(Path(args.report_out), report)
    if args.model_out:
        model_path = Path(args.model_out).expanduser().resolve()
        model_path.parent.mkdir(parents=True, exist_ok=True)
        model.booster_.save_model(str(model_path))
        if args.verbose:
            print(f"[saved] model -> {model_path}", file=sys.stderr)

    return report


# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

def print_summary(report: dict) -> None:
    ds = report["data_summary"]
    m = report["metrics"]
    print("LightGBM vacancy training summary")
    print(f"- Snapshots: {ds['snapshot_count']}  (train {ds['train_snapshots']} / test {ds['test_snapshots']})")
    print(f"- Range:     {ds['first_snapshot']} -> {ds['last_snapshot']}")
    print(f"- Parks:     {ds['park_count']}  examples: train {ds['train_examples']} / test {ds['test_examples']}")
    for split in ("train", "test"):
        if split not in m:
            continue
        mm = m[split]["model"]
        bl = m[split]["lag_1_baseline"]
        gain_str = ""
        if mm["mae"] is not None and bl["mae"] is not None:
            gain = bl["mae"] - mm["mae"]
            gain_str = f"  (gain vs lag_1: {gain:+.4f})"
        print(f"- {split} model  MAE {_fmt(mm['mae'])}  RMSE {_fmt(mm['rmse'])}  n={mm['count']}{gain_str}")
        print(f"- {split} lag_1  MAE {_fmt(bl['mae'])}  RMSE {_fmt(bl['rmse'])}")

    print("- Top features by importance:")
    for item in report.get("top_features", [])[:10]:
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
    if args.sample_every < 1:
        print("--sample-every must be >= 1", file=sys.stderr)
        return 1
    try:
        report = run_training(args)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    print_summary(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
