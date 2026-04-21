#!/usr/bin/env python3
"""Train a lightweight vacancy forecasting baseline from mirrored gov_vacancy data.

This script is intentionally standard-library only so it can run in the current
workspace without extra Python packages. It trains a small expert ensemble to
predict the next observed vacancy value for one vehicle type, using:

- the most recent value
- short moving averages
- park-level hour-of-day averages
- park-level day-of-week averages
- global hour-of-day averages

The ensemble weights are learned online on the training split with a simple
multiplicative update rule. Evaluation is walk-forward on a later time slice,
which is a good fit for deployment-style "predict next snapshot" forecasting.

Examples:
  python3 scripts/train_gov_vacancy_baseline.py \
    --data-root /Users/yuntungyeung/Downloads/gov_vacancy \
    --report-out tmp/vacancy_report.json \
    --model-out tmp/vacancy_model.json

  python3 scripts/train_gov_vacancy_baseline.py \
    --data-root /Users/yuntungyeung/Downloads/gov_vacancy \
    --park-id 27 --park-id 30 --max-files 2000
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
from typing import Iterable


DEFAULT_EXPERT_WEIGHTS = {
    "lag_1": 0.46,
    "mean_3": 0.18,
    "mean_6": 0.10,
    "park_hour": 0.14,
    "park_dow": 0.07,
    "global_hour": 0.05,
}

# Minimum weight any expert can hold (before renormalisation). This prevents
# slow-but-informative experts from being permanently eliminated by the
# multiplicative update when lag_1 dominates for a long run.
DEFAULT_MIN_EXPERT_WEIGHT = 0.02

TIMESTAMP_RE = re.compile(r"(\d{4}-\d{2}-\d{2} \d{2}-\d{2}-\d{2})")


@dataclass
class MetricAccumulator:
    count: int = 0
    abs_error_total: float = 0.0
    squared_error_total: float = 0.0

    def add(self, prediction: float, actual: float) -> None:
        error = prediction - actual
        self.count += 1
        self.abs_error_total += abs(error)
        self.squared_error_total += error * error

    def as_dict(self) -> dict[str, float | int | None]:
        rmse = (
            math.sqrt(self.squared_error_total / self.count)
            if self.count
            else None
        )
        mae = self.abs_error_total / self.count if self.count else None
        return {"count": self.count, "mae": mae, "rmse": rmse}


@dataclass
class MeanAccumulator:
    total: float = 0.0
    count: int = 0

    def add(self, value: float) -> None:
        self.total += value
        self.count += 1

    @property
    def mean(self) -> float | None:
        if self.count == 0:
            return None
        return self.total / self.count


@dataclass
class ParkState:
    recent_values: deque[float] = field(default_factory=lambda: deque(maxlen=6))
    recent_times: deque[dt.datetime] = field(
        default_factory=lambda: deque(maxlen=6),
    )
    pending_examples: deque[PendingExample] = field(default_factory=deque)
    hour_stats: list[MeanAccumulator] = field(
        default_factory=lambda: [MeanAccumulator() for _ in range(24)],
    )
    dow_stats: list[MeanAccumulator] = field(
        default_factory=lambda: [MeanAccumulator() for _ in range(7)],
    )
    observation_count: int = 0
    missing_count: int = 0

    def reset_recent_history(self) -> None:
        self.recent_values.clear()
        self.recent_times.clear()
        self.pending_examples.clear()

    def update(self, timestamp: dt.datetime, value: float) -> None:
        self.recent_values.append(value)
        self.recent_times.append(timestamp)
        self.hour_stats[timestamp.hour].add(value)
        self.dow_stats[timestamp.weekday()].add(value)
        self.observation_count += 1


@dataclass
class PendingExample:
    split: str
    experts: dict[str, float]
    lag_prediction: float


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Train a lightweight next-snapshot vacancy predictor from mirrored "
            "gov_vacancy JSON history."
        ),
    )
    parser.add_argument(
        "--data-root",
        required=True,
        help=(
            "Path to gov_vacancy root or directly to "
            "api.data.gov.hk/v1-carpark-info-vacancy."
        ),
    )
    parser.add_argument(
        "--vehicle-type",
        default="privateCar",
        help="Vehicle section to train on. Default: privateCar",
    )
    parser.add_argument(
        "--target-key",
        default="vacancy",
        help="Numeric key inside each vehicle entry to predict. Default: vacancy",
    )
    parser.add_argument(
        "--train-ratio",
        type=float,
        default=0.8,
        help=(
            "Chronological train split ratio. Use 1.0 to train on all data with "
            "no holdout evaluation."
        ),
    )
    parser.add_argument(
        "--learning-rate",
        type=float,
        default=0.01,
        help=(
            "Learning rate for the online ensemble update. "
            "Lower values prevent expert weights from collapsing. Default: 0.01"
        ),
    )
    parser.add_argument(
        "--min-expert-weight",
        type=float,
        default=DEFAULT_MIN_EXPERT_WEIGHT,
        help=(
            "Floor weight for each expert before renormalisation. "
            "Prevents multiplicative decay from permanently eliminating an expert. "
            f"Default: {DEFAULT_MIN_EXPERT_WEIGHT}"
        ),
    )
    parser.add_argument(
        "--horizon-steps",
        type=int,
        default=1,
        help=(
            "Forecast horizon in observed snapshots. With 10-minute history, "
            "6 is roughly 1 hour ahead. Default: 1"
        ),
    )
    parser.add_argument(
        "--min-history",
        type=int,
        default=3,
        help="Minimum recent observations required before producing predictions.",
    )
    parser.add_argument(
        "--reset-gap-minutes",
        type=float,
        default=180.0,
        help="Reset per-park recent lag history after larger gaps. Default: 180",
    )
    parser.add_argument(
        "--sample-every",
        type=int,
        default=1,
        help="Use every Nth snapshot file. Default: 1",
    )
    parser.add_argument(
        "--max-files",
        type=int,
        default=0,
        help="Optional cap on number of snapshot files after sampling.",
    )
    parser.add_argument(
        "--park-id",
        action="append",
        default=[],
        help="Optional park id filter. Can be passed multiple times.",
    )
    parser.add_argument(
        "--top-parks",
        type=int,
        default=10,
        help="How many parks to include in the summary ranking.",
    )
    parser.add_argument(
        "--report-out",
        default="",
        help="Optional path to write the JSON training report.",
    )
    parser.add_argument(
        "--model-out",
        default="",
        help="Optional path to write the trained model JSON.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print progress information to stderr.",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.sample_every < 1:
        parser.error("--sample-every must be >= 1")
    if not 0 < args.train_ratio <= 1:
        parser.error("--train-ratio must be within (0, 1]")
    if args.min_history < 1:
        parser.error("--min-history must be >= 1")
    if args.horizon_steps < 1:
        parser.error("--horizon-steps must be >= 1")

    try:
        report = run_training(args)
    except Exception as exc:  # pragma: no cover - CLI guard
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    print_summary(report)
    return 0


def run_training(args: argparse.Namespace) -> dict[str, object]:
    root = resolve_data_root(Path(args.data_root))
    snapshot_files = discover_snapshot_files(
        root,
        sample_every=args.sample_every,
        max_files=args.max_files,
    )
    if not snapshot_files:
        raise RuntimeError(f"No snapshot JSON files found under {root}")

    train_cutoff = len(snapshot_files)
    if args.train_ratio < 1:
        train_cutoff = max(1, min(len(snapshot_files) - 1, int(len(snapshot_files) * args.train_ratio)))

    park_filter = set(args.park_id)
    weights = dict(DEFAULT_EXPERT_WEIGHTS)
    global_hour_stats = [MeanAccumulator() for _ in range(24)]
    states: dict[str, ParkState] = {}

    split_metrics = {
        "train": MetricAccumulator(),
        "test": MetricAccumulator(),
    }
    baseline_metrics = {
        "train": MetricAccumulator(),
        "test": MetricAccumulator(),
    }
    park_metrics: dict[str, dict[str, MetricAccumulator]] = {}

    processed_rows = 0
    skipped_rows = 0
    stale_rows = 0
    first_ts: dt.datetime | None = None
    last_ts: dt.datetime | None = None

    for index, snapshot_path in enumerate(snapshot_files):
        split = "train" if index < train_cutoff else "test"
        timestamp = parse_snapshot_timestamp(snapshot_path)
        first_ts = first_ts or timestamp
        last_ts = timestamp

        if args.verbose and index % 500 == 0:
            print(
                f"[progress] file {index + 1}/{len(snapshot_files)} split={split} path={snapshot_path.name}",
                file=sys.stderr,
            )

        payload = json.loads(snapshot_path.read_text(encoding="utf-8"))
        rows = payload.get("results", [])
        if not isinstance(rows, list):
            continue

        for row in rows:
            if not isinstance(row, dict):
                continue
            park_id = str(row.get("park_Id", "")).strip()
            if not park_id:
                skipped_rows += 1
                continue
            if park_filter and park_id not in park_filter:
                continue

            current_value = extract_vehicle_value(
                row.get(args.vehicle_type),
                target_key=args.target_key,
            )
            if current_value is None:
                skipped_rows += 1
                continue

            state = states.setdefault(park_id, ParkState())
            freshness_minutes = extract_freshness_minutes(
                timestamp,
                row.get(args.vehicle_type),
            )
            if freshness_minutes is not None and freshness_minutes > 60:
                stale_rows += 1

            if state.recent_times:
                gap_minutes = (timestamp - state.recent_times[-1]).total_seconds() / 60
                if gap_minutes > args.reset_gap_minutes:
                    state.reset_recent_history()

            if len(state.pending_examples) >= args.horizon_steps:
                ready = state.pending_examples.popleft()
                model_prediction = clamp_non_negative(
                    weighted_prediction(ready.experts, weights),
                )
                lag_prediction = clamp_non_negative(ready.lag_prediction)

                split_metrics[ready.split].add(model_prediction, current_value)
                baseline_metrics[ready.split].add(lag_prediction, current_value)

                park_bucket = park_metrics.setdefault(
                    park_id,
                    {"model": MetricAccumulator(), "lag_1": MetricAccumulator()},
                )
                park_bucket["model"].add(model_prediction, current_value)
                park_bucket["lag_1"].add(lag_prediction, current_value)

                if ready.split == "train":
                    update_weights(
                        weights=weights,
                        experts=ready.experts,
                        actual=current_value,
                        learning_rate=args.learning_rate,
                        min_expert_weight=args.min_expert_weight,
                    )

            experts = build_expert_predictions(
                park_state=state,
                global_hour_stats=global_hour_stats,
                target_timestamp=timestamp,
            )

            if len(state.recent_values) >= args.min_history and experts:
                state.pending_examples.append(
                    PendingExample(
                        split=split,
                        experts=experts,
                        lag_prediction=state.recent_values[-1],
                    ),
                )

            state.update(timestamp, current_value)
            global_hour_stats[timestamp.hour].add(current_value)
            processed_rows += 1

    report = {
        "config": {
            "data_root": str(root),
            "vehicle_type": args.vehicle_type,
            "target_key": args.target_key,
            "train_ratio": args.train_ratio,
            "learning_rate": args.learning_rate,
            "min_expert_weight": args.min_expert_weight,
            "horizon_steps": args.horizon_steps,
            "min_history": args.min_history,
            "reset_gap_minutes": args.reset_gap_minutes,
            "sample_every": args.sample_every,
            "max_files": args.max_files or None,
            "park_filter": sorted(park_filter),
        },
        "data_summary": {
            "snapshot_file_count": len(snapshot_files),
            "train_snapshot_file_count": train_cutoff,
            "test_snapshot_file_count": len(snapshot_files) - train_cutoff,
            "first_snapshot": first_ts.isoformat() if first_ts else None,
            "last_snapshot": last_ts.isoformat() if last_ts else None,
            "processed_rows": processed_rows,
            "skipped_rows": skipped_rows,
            "stale_rows_over_60_minutes": stale_rows,
            "park_count": len(states),
        },
        "weights": dict(weights),
        "metrics": {
            "train": {
                "model": split_metrics["train"].as_dict(),
                "lag_1_baseline": baseline_metrics["train"].as_dict(),
            },
            "test": {
                "model": split_metrics["test"].as_dict(),
                "lag_1_baseline": baseline_metrics["test"].as_dict(),
            },
        },
        "top_parks": rank_parks(park_metrics, top_n=args.top_parks),
    }

    if args.report_out:
        write_json(Path(args.report_out), report)
    if args.model_out:
        model_payload = {
            "trained_at": dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
            "config": report["config"],
            "weights": dict(weights),
            "notes": {
                "prediction_target": "next observed vacancy snapshot",
                "recommended_inference_inputs": [
                    "latest vacancy history for the same park",
                    "current timestamp",
                    "hour-of-day historical means",
                    "day-of-week historical means",
                ],
            },
        }
        write_json(Path(args.model_out), model_payload)

    return report


def resolve_data_root(path: Path) -> Path:
    path = path.expanduser().resolve()
    if (path / "api.data.gov.hk" / "v1-carpark-info-vacancy").exists():
        return path / "api.data.gov.hk" / "v1-carpark-info-vacancy"
    if path.name == "v1-carpark-info-vacancy":
        return path
    raise RuntimeError(
        "Expected --data-root to contain api.data.gov.hk/v1-carpark-info-vacancy "
        f"or point directly at that folder: {path}",
    )


def discover_snapshot_files(
    root: Path,
    *,
    sample_every: int,
    max_files: int,
) -> list[Path]:
    files = sorted(root.glob("*/*/*/*.json"))
    if sample_every > 1:
        files = files[::sample_every]
    if max_files > 0:
        files = files[:max_files]
    return files


def parse_snapshot_timestamp(path: Path) -> dt.datetime:
    match = TIMESTAMP_RE.search(path.name)
    if not match:
        raise RuntimeError(f"Could not parse timestamp from file name: {path}")
    return dt.datetime.strptime(match.group(1), "%Y-%m-%d %H-%M-%S")


def extract_vehicle_value(raw_vehicle: object, *, target_key: str) -> float | None:
    if not isinstance(raw_vehicle, list) or not raw_vehicle:
        return None
    total = 0.0
    found = False
    for item in raw_vehicle:
        if not isinstance(item, dict):
            continue
        value = item.get(target_key)
        if isinstance(value, (int, float)):
            total += float(value)
            found = True
    if not found:
        return None
    return total


def extract_freshness_minutes(
    snapshot_timestamp: dt.datetime,
    raw_vehicle: object,
) -> float | None:
    if not isinstance(raw_vehicle, list) or not raw_vehicle:
        return None
    freshest: dt.datetime | None = None
    for item in raw_vehicle:
        if not isinstance(item, dict):
            continue
        raw_last_update = item.get("lastupdate")
        if not isinstance(raw_last_update, str) or not raw_last_update:
            continue
        try:
            parsed = dt.datetime.strptime(raw_last_update, "%Y-%m-%d %H:%M:%S")
        except ValueError:
            continue
        if freshest is None or parsed > freshest:
            freshest = parsed
    if freshest is None:
        return None
    return max(0.0, (snapshot_timestamp - freshest).total_seconds() / 60.0)


def build_expert_predictions(
    *,
    park_state: ParkState,
    global_hour_stats: list[MeanAccumulator],
    target_timestamp: dt.datetime,
) -> dict[str, float]:
    experts: dict[str, float] = {}
    recent = list(park_state.recent_values)
    if not recent:
        return experts

    experts["lag_1"] = recent[-1]
    if len(recent) >= 3:
        experts["mean_3"] = sum(recent[-3:]) / 3.0
    elif recent:
        experts["mean_3"] = sum(recent) / len(recent)

    experts["mean_6"] = sum(recent) / len(recent)

    park_hour_mean = park_state.hour_stats[target_timestamp.hour].mean
    if park_hour_mean is not None:
        experts["park_hour"] = park_hour_mean

    park_dow_mean = park_state.dow_stats[target_timestamp.weekday()].mean
    if park_dow_mean is not None:
        experts["park_dow"] = park_dow_mean

    global_hour_mean = global_hour_stats[target_timestamp.hour].mean
    if global_hour_mean is not None:
        experts["global_hour"] = global_hour_mean

    return experts


def weighted_prediction(experts: dict[str, float], weights: dict[str, float]) -> float:
    numerator = 0.0
    denominator = 0.0
    for name, prediction in experts.items():
        weight = weights.get(name, 0.0)
        if weight <= 0:
            continue
        numerator += prediction * weight
        denominator += weight
    if denominator <= 0:
        return next(iter(experts.values()))
    return numerator / denominator


def update_weights(
    *,
    weights: dict[str, float],
    experts: dict[str, float],
    actual: float,
    learning_rate: float,
    min_expert_weight: float = DEFAULT_MIN_EXPERT_WEIGHT,
) -> None:
    scale = max(1.0, actual)
    for name, prediction in experts.items():
        current_weight = weights.get(name, 0.0)
        if current_weight <= 0:
            continue
        normalized_error = min(4.0, abs(prediction - actual) / scale)
        decayed = current_weight * math.exp(-learning_rate * normalized_error)
        weights[name] = max(min_expert_weight, decayed)
    renormalize_weights(weights)


def renormalize_weights(weights: dict[str, float]) -> None:
    total = sum(value for value in weights.values() if value > 0)
    if total <= 0:
        weights.clear()
        weights.update(DEFAULT_EXPERT_WEIGHTS)
        return
    for name in list(weights.keys()):
        weights[name] = weights[name] / total


def clamp_non_negative(value: float) -> float:
    return value if value >= 0 else 0.0


def rank_parks(
    park_metrics: dict[str, dict[str, MetricAccumulator]],
    *,
    top_n: int,
) -> list[dict[str, object]]:
    ranked: list[dict[str, object]] = []
    for park_id, bucket in park_metrics.items():
        model_stats = bucket["model"].as_dict()
        lag_stats = bucket["lag_1"].as_dict()
        ranked.append(
            {
                "park_id": park_id,
                "model": model_stats,
                "lag_1_baseline": lag_stats,
                "mae_gain_vs_lag_1": compute_gain(
                    lag_stats.get("mae"),
                    model_stats.get("mae"),
                ),
            },
        )
    ranked.sort(
        key=lambda item: (
            -(item["model"]["count"] or 0),
            item["model"]["mae"] if item["model"]["mae"] is not None else float("inf"),
        ),
    )
    return ranked[:top_n]


def compute_gain(baseline_mae: object, model_mae: object) -> float | None:
    if not isinstance(baseline_mae, (int, float)) or not isinstance(model_mae, (int, float)):
        return None
    return baseline_mae - model_mae


def write_json(path: Path, payload: object) -> None:
    path = path.expanduser().resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def print_summary(report: dict[str, object]) -> None:
    data_summary = report["data_summary"]
    metrics = report["metrics"]
    weights = report["weights"]

    print("Gov vacancy training summary")
    print(
        f"- Files: {data_summary['snapshot_file_count']} "
        f"(train {data_summary['train_snapshot_file_count']} / "
        f"test {data_summary['test_snapshot_file_count']})",
    )
    print(
        f"- Range: {data_summary['first_snapshot']} -> {data_summary['last_snapshot']}",
    )
    print(
        f"- Parks: {data_summary['park_count']}, rows: {data_summary['processed_rows']}, "
        f"stale rows (>60 min): {data_summary['stale_rows_over_60_minutes']}",
    )
    print("- Learned weights:")
    for name, value in sorted(weights.items()):
        print(f"  - {name}: {value:.4f}")

    for split in ("train", "test"):
        model_stats = metrics[split]["model"]
        baseline_stats = metrics[split]["lag_1_baseline"]
        print(
            f"- {split} model MAE: {format_metric(model_stats['mae'])} "
            f"(RMSE {format_metric(model_stats['rmse'])}, n={model_stats['count']})",
        )
        print(
            f"- {split} lag_1 MAE: {format_metric(baseline_stats['mae'])} "
            f"(RMSE {format_metric(baseline_stats['rmse'])}, n={baseline_stats['count']})",
        )

    top_parks = report.get("top_parks", [])
    if isinstance(top_parks, Iterable):
        print("- Top parks by evaluated volume:")
        for item in top_parks:
            if not isinstance(item, dict):
                continue
            model_stats = item["model"]
            lag_stats = item["lag_1_baseline"]
            print(
                f"  - park {item['park_id']}: "
                f"model MAE {format_metric(model_stats['mae'])}, "
                f"lag_1 MAE {format_metric(lag_stats['mae'])}, "
                f"gain {format_metric(item['mae_gain_vs_lag_1'])}",
            )


def format_metric(value: object) -> str:
    if not isinstance(value, (int, float)):
        return "n/a"
    return f"{value:.4f}"


if __name__ == "__main__":
    raise SystemExit(main())
