"""Vacancy prediction API.

Serves vacancy forecasts for:
- government carparks via a trained LightGBM model
- metered parking street groups via a trained LightGBM model

Environment variables
---------------------
GOV_VACANCY_ROOT   Path to the mirrored gov_vacancy directory.
                   Expected layout: <root>/api.data.gov.hk/v1-carpark-info-vacancy/YYYY/MM/DD/<ts>.json
GOV_METERS_ROOT    Path to the mirrored gov_meters directory.
                   Expected layout:
                   <root>/resource.data.one.gov.hk/td-psiparkingspaces-{spaceinfo,occupancystatus}/YYYY/MM/DD/<ts>.csv
MODEL_PATH         Path to the saved LightGBM model (.txt).
HISTORY_SNAPSHOTS  How many recent snapshots to load for lag features (default 12).
PORT               Port to listen on (default 8081).
"""

from __future__ import annotations

import datetime as dt
import csv
import json
import math
import os
import re
import threading
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import lightgbm as lgb
import numpy as np
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

_GOV_VACANCY_ROOT = Path(os.getenv("GOV_VACANCY_ROOT", "gov_vacancy"))
_GOV_METERS_ROOT = Path(os.getenv("GOV_METERS_ROOT", "gov_meters"))
_MODEL_PATH = Path(os.getenv("MODEL_PATH", "tmp/lgbm_model_h6_final.txt"))
_METER_MODEL_PATH = Path(os.getenv("METER_MODEL_PATH", "tmp/meter_model_full.txt"))
_HISTORY_SNAPSHOTS = int(os.getenv("HISTORY_SNAPSHOTS", "12"))
_HORIZON_STEPS = 6
_MAX_LAG = 6
_METER_HORIZON_STEPS = 12
_METER_MAX_LAG = 12
_TIMESTAMP_RE = re.compile(r"(\d{4}-\d{2}-\d{2} \d{2}-\d{2}-\d{2})")


# ---------------------------------------------------------------------------
# Feature engineering (mirrors train_gov_vacancy_lgbm.py)
# ---------------------------------------------------------------------------

@dataclass
class ParkBuffer:
    values: deque[float] = field(default_factory=lambda: deque(maxlen=_MAX_LAG))
    times: deque[dt.datetime] = field(default_factory=lambda: deque(maxlen=_MAX_LAG))
    hour_sums: list[float] = field(default_factory=lambda: [0.0] * 24)
    hour_counts: list[int] = field(default_factory=lambda: [0] * 24)
    dow_sums: list[float] = field(default_factory=lambda: [0.0] * 7)
    dow_counts: list[int] = field(default_factory=lambda: [0] * 7)
    max_observed: float = 0.0

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


@dataclass
class MeterGroupBuffer:
    values: deque[float] = field(
        default_factory=lambda: deque(maxlen=_METER_MAX_LAG)
    )
    times: deque[dt.datetime] = field(
        default_factory=lambda: deque(maxlen=_METER_MAX_LAG)
    )
    hour_sums: list[float] = field(default_factory=lambda: [0.0] * 24)
    hour_counts: list[int] = field(default_factory=lambda: [0] * 24)
    dow_sums: list[float] = field(default_factory=lambda: [0.0] * 7)
    dow_counts: list[int] = field(default_factory=lambda: [0] * 7)

    def push(self, ts: dt.datetime, v: float) -> None:
        self.values.append(v)
        self.times.append(ts)
        h, d = ts.hour, ts.weekday()
        self.hour_sums[h] += v
        self.hour_counts[h] += 1
        self.dow_sums[d] += v
        self.dow_counts[d] += 1

    def hour_mean(self, h: int) -> float:
        return (
            self.hour_sums[h] / self.hour_counts[h]
            if self.hour_counts[h]
            else float("nan")
        )

    def dow_mean(self, d: int) -> float:
        return (
            self.dow_sums[d] / self.dow_counts[d]
            if self.dow_counts[d]
            else float("nan")
        )


def _make_features(ts: dt.datetime, buf: ParkBuffer) -> dict[str, float]:
    vals = list(buf.values)
    n = len(vals)
    h, d = ts.hour, ts.weekday()
    feats: dict[str, float] = {}

    feats["hour_sin"] = math.sin(2 * math.pi * h / 24)
    feats["hour_cos"] = math.cos(2 * math.pi * h / 24)
    feats["dow_sin"] = math.sin(2 * math.pi * d / 7)
    feats["dow_cos"] = math.cos(2 * math.pi * d / 7)
    feats["is_weekend"] = float(d >= 5)

    for i in range(1, _MAX_LAG + 1):
        feats[f"lag_{i}"] = vals[-i] if n >= i else float("nan")

    w3 = vals[-3:] if n >= 3 else vals
    w6 = vals[-6:] if n >= 6 else vals
    feats["roll_mean_3"] = float(np.mean(w3)) if w3 else float("nan")
    feats["roll_mean_6"] = float(np.mean(w6)) if w6 else float("nan")
    feats["roll_std_3"] = float(np.std(w3)) if len(w3) > 1 else 0.0
    feats["roll_std_6"] = float(np.std(w6)) if len(w6) > 1 else 0.0

    feats["park_hour_mean"] = buf.hour_mean(h)
    feats["park_dow_mean"] = buf.dow_mean(d)

    cap = buf.max_observed if buf.max_observed > 0 else float("nan")
    feats["park_capacity"] = cap
    lag1 = vals[-1] if n >= 1 else float("nan")
    feats["occupancy_ratio"] = lag1 / cap if (n >= 1 and not math.isnan(cap) and cap > 0) else float("nan")

    return feats


def _make_meter_features(ts: dt.datetime, buf: MeterGroupBuffer, total_spaces: int) -> dict[str, float]:
    """Build feature vector for the meter LightGBM model (mirrors train_gov_meter_vacancy_lgbm.py)."""
    vals = list(buf.values)
    n = len(vals)
    h, d = ts.hour, ts.weekday()
    feats: dict[str, float] = {}

    feats["hour_sin"] = math.sin(2 * math.pi * h / 24)
    feats["hour_cos"] = math.cos(2 * math.pi * h / 24)
    feats["dow_sin"] = math.sin(2 * math.pi * d / 7)
    feats["dow_cos"] = math.cos(2 * math.pi * d / 7)
    feats["is_weekend"] = float(d >= 5)

    for i in range(1, _METER_MAX_LAG + 1):
        feats[f"lag_{i}"] = vals[-i] if n >= i else float("nan")

    w3 = vals[-3:] if n >= 3 else vals
    w6 = vals[-6:] if n >= 6 else vals
    feats["roll_mean_3"] = float(np.mean(w3)) if w3 else float("nan")
    feats["roll_mean_6"] = float(np.mean(w6)) if w6 else float("nan")
    feats["roll_std_3"] = float(np.std(w3)) if len(w3) > 1 else 0.0
    feats["roll_std_6"] = float(np.std(w6)) if len(w6) > 1 else 0.0

    feats["group_hour_mean"] = buf.hour_mean(h)
    feats["group_dow_mean"] = buf.dow_mean(d)

    cap = float(total_spaces) if total_spaces > 0 else float("nan")
    feats["total_spaces"] = cap
    lag1 = vals[-1] if n >= 1 else float("nan")
    feats["vacancy_ratio"] = lag1 / cap if (n >= 1 and not math.isnan(cap) and cap > 0) else float("nan")

    return feats


# ---------------------------------------------------------------------------
# Snapshot utilities
# ---------------------------------------------------------------------------

def _resolve_vacancy_root(root: Path) -> Path:
    root = root.expanduser().resolve()
    candidate = root / "api.data.gov.hk" / "v1-carpark-info-vacancy"
    if candidate.exists():
        return candidate
    if root.name == "v1-carpark-info-vacancy":
        return root
    raise RuntimeError(f"Cannot find v1-carpark-info-vacancy under {root}")


def _resolve_meter_root(root: Path) -> Path:
    root = root.expanduser().resolve()
    candidate = root / "resource.data.one.gov.hk"
    if candidate.exists():
        return candidate
    if root.name == "resource.data.one.gov.hk":
        return root
    raise RuntimeError(f"Cannot find resource.data.one.gov.hk under {root}")


def _list_snapshots(root: Path) -> list[Path]:
    return sorted(root.glob("*/*/*/*.json"))


def _list_meter_occupancy_snapshots(root: Path) -> list[Path]:
    return sorted(
        (root / "td-psiparkingspaces-occupancystatus").glob("*/*/*/*.csv")
    )


def _list_meter_spaceinfo_snapshots(root: Path) -> list[Path]:
    return sorted((root / "td-psiparkingspaces-spaceinfo").glob("*/*/*/*.csv"))


def _parse_ts(path: Path) -> Optional[dt.datetime]:
    m = _TIMESTAMP_RE.search(path.name)
    if not m:
        return None
    try:
        return dt.datetime.strptime(m.group(1), "%Y-%m-%d %H-%M-%S")
    except ValueError:
        return None


def _extract_value(raw_vehicle: object, target_key: str = "vacancy") -> Optional[float]:
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


def _meter_group_key(
    *,
    vehicle_type: str,
    operating_period: str,
    district_en: str,
    street_en: str,
    section_en: str,
) -> str:
    section = section_en or "-"
    return (
        f"{vehicle_type}|{operating_period}|{district_en}|"
        f"{street_en}|{section}"
    )


def _read_meter_csv(path: Path, skip_lines: int = 0) -> list[dict[str, str]]:
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    if skip_lines:
        if len(lines) <= skip_lines:
            return []
        lines = lines[skip_lines:]
    reader = csv.DictReader(lines)
    return [
        {str(k): (str(v).strip() if v is not None else "") for k, v in row.items()}
        for row in reader
        if row
    ]


def _load_meter_group_maps(
    meter_root: Path,
) -> tuple[dict[str, str], dict[str, int]]:
    space_files = _list_meter_spaceinfo_snapshots(meter_root)
    if not space_files:
        raise RuntimeError(f"No meter spaceinfo snapshots found under {meter_root}")

    latest_space = space_files[-1]
    space_to_group: dict[str, str] = {}
    group_totals: dict[str, int] = {}
    for row in _read_meter_csv(latest_space, skip_lines=2):
        parking_space_id = row.get("ParkingSpaceId", "").strip()
        if not parking_space_id:
            continue
        group_key = _meter_group_key(
            vehicle_type=row.get("VehicleType", "").strip(),
            operating_period=row.get("OperatingPeriod", "").strip(),
            district_en=row.get("District", "").strip(),
            street_en=row.get("Street", "").strip(),
            section_en=row.get("SectionOfStreet", "").strip(),
        )
        space_to_group[parking_space_id] = group_key
        group_totals[group_key] = group_totals.get(group_key, 0) + 1

    return space_to_group, group_totals


def _safe_mean(values: list[float]) -> float:
    return float(np.mean(values)) if values else float("nan")


def _predict_meter_from_buffer(
    *,
    now: dt.datetime,
    buf: MeterGroupBuffer,
    total_spaces: int,
) -> tuple[int, str]:
    if not buf.values:
        raise ValueError("No history available")

    current = float(buf.values[-1])
    recent_values = list(buf.values)
    recent_mean = _safe_mean(recent_values[-6:])
    hour_mean = buf.hour_mean(now.hour)
    dow_mean = buf.dow_mean(now.weekday())

    components = [(current, 0.50)]
    if not math.isnan(recent_mean):
        components.append((recent_mean, 0.20))
    if not math.isnan(hour_mean):
        components.append((hour_mean, 0.20))
    if not math.isnan(dow_mean):
        components.append((dow_mean, 0.10))

    predicted = sum(value * weight for value, weight in components) / sum(
        weight for _, weight in components
    )

    if len(recent_values) >= 4:
        deltas = [
            recent_values[i] - recent_values[i - 1]
            for i in range(1, len(recent_values))
        ]
        recent_trend = _safe_mean(deltas[-3:])
        if not math.isnan(recent_trend):
            predicted += recent_trend * 3

    predicted = max(0.0, min(float(total_spaces), predicted))

    confidence = "ok"
    if len(buf.values) < 6:
        confidence = "low_history"
    elif buf.times and (now - buf.times[-1]).total_seconds() / 60 > 20:
        confidence = "stale"

    return int(round(predicted)), confidence


# ---------------------------------------------------------------------------
# Model store (singleton, refreshed periodically)
# ---------------------------------------------------------------------------

class VacancyPredictor:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._model: Optional[lgb.Booster] = None
        self._feature_names: list[str] = []
        self._buffers: dict[str, ParkBuffer] = {}
        self._last_snapshot_path: Optional[Path] = None
        self._loaded_at: Optional[dt.datetime] = None
        self._vacancy_root: Optional[Path] = None

    def load(self, model_path: Path, vacancy_root: Path, history_snapshots: int) -> None:
        model_path = model_path.expanduser().resolve()
        if not model_path.exists():
            raise RuntimeError(f"Model file not found: {model_path}")

        booster = lgb.Booster(model_file=str(model_path))
        vroot = _resolve_vacancy_root(vacancy_root)
        snapshots = _list_snapshots(vroot)
        if not snapshots:
            raise RuntimeError(f"No snapshots found under {vroot}")

        recent = snapshots[-history_snapshots:]
        buffers: dict[str, ParkBuffer] = {}

        for snap_path in recent:
            ts = _parse_ts(snap_path)
            if ts is None:
                continue
            try:
                payload = json.loads(snap_path.read_text(encoding="utf-8"))
            except Exception:
                continue
            for row in payload.get("results", []):
                if not isinstance(row, dict):
                    continue
                park_id = str(row.get("park_Id", "")).strip()
                if not park_id:
                    continue
                value = _extract_value(row.get("privateCar"))
                if value is None:
                    continue
                buf = buffers.setdefault(park_id, ParkBuffer())
                if buf.times and (ts - buf.times[-1]).total_seconds() / 60 > 180:
                    buf.values.clear()
                    buf.times.clear()
                buf.push(ts, value)

        # Derive feature column order from a dummy prediction
        dummy_park = next(iter(buffers.values())) if buffers else ParkBuffer()
        dummy_ts = dt.datetime.now()
        dummy_feats = _make_features(dummy_ts, dummy_park)
        feature_names = list(dummy_feats.keys())

        with self._lock:
            self._model = booster
            self._feature_names = feature_names
            self._buffers = buffers
            self._last_snapshot_path = snapshots[-1]
            self._loaded_at = dt.datetime.now(dt.timezone.utc)
            self._vacancy_root = vroot

        print(
            f"[vacancy_api] Model loaded: {len(buffers)} parks, "
            f"last snapshot={snapshots[-1].name}, "
            f"features={feature_names}",
            flush=True,
        )

    def refresh(self) -> int:
        """Load any new snapshots since last load. Returns count of new snapshots ingested."""
        with self._lock:
            if self._vacancy_root is None or self._last_snapshot_path is None:
                return 0
            all_snaps = _list_snapshots(self._vacancy_root)

        # find new ones after last known
        try:
            last_idx = all_snaps.index(self._last_snapshot_path)
            new_snaps = all_snaps[last_idx + 1:]
        except ValueError:
            new_snaps = []

        if not new_snaps:
            return 0

        buffers_copy: dict[str, ParkBuffer]
        with self._lock:
            buffers_copy = dict(self._buffers)

        for snap_path in new_snaps:
            ts = _parse_ts(snap_path)
            if ts is None:
                continue
            try:
                payload = json.loads(snap_path.read_text(encoding="utf-8"))
            except Exception:
                continue
            for row in payload.get("results", []):
                if not isinstance(row, dict):
                    continue
                park_id = str(row.get("park_Id", "")).strip()
                if not park_id:
                    continue
                value = _extract_value(row.get("privateCar"))
                if value is None:
                    continue
                buf = buffers_copy.setdefault(park_id, ParkBuffer())
                if buf.times and (ts - buf.times[-1]).total_seconds() / 60 > 180:
                    buf.values.clear()
                    buf.times.clear()
                buf.push(ts, value)

        with self._lock:
            self._buffers = buffers_copy
            self._last_snapshot_path = new_snaps[-1]

        return len(new_snaps)

    def predict(self, park_id: str, vehicle_type: str = "privateCar") -> dict:
        with self._lock:
            model = self._model
            feature_names = list(self._feature_names)
            buf = self._buffers.get(park_id)
            loaded_at = self._loaded_at

        if model is None:
            raise RuntimeError("Model not loaded")
        if buf is None or len(buf.values) == 0:
            raise ValueError(f"No history for park_id={park_id!r}")

        now = dt.datetime.now()
        feats = _make_features(now, buf)
        feat_row = np.array([[feats.get(k, float("nan")) for k in feature_names]], dtype=np.float32)

        lag_1 = float(buf.values[-1])
        # delta mode: model predicts (target - lag_1)
        delta = float(model.predict(feat_row)[0])
        predicted = max(0.0, lag_1 + delta)

        confidence = "ok"
        if len(buf.values) < _MAX_LAG:
            confidence = "low_history"
        elif buf.times and (now - buf.times[-1]).total_seconds() / 60 > 60:
            confidence = "stale"

        return {
            "park_id": park_id,
            "vehicle_type": vehicle_type,
            "current_vacancy": int(round(lag_1)),
            "predicted_vacancy": int(round(predicted)),
            "horizon_steps": _HORIZON_STEPS,
            "horizon_minutes": _HORIZON_STEPS * 10,
            "predicted_at": now.isoformat(),
            "confidence": confidence,
            "model_loaded_at": loaded_at.isoformat() if loaded_at else None,
        }


_predictor = VacancyPredictor()


class MeterVacancyPredictor:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._model: Optional[lgb.Booster] = None
        self._feature_names: list[str] = []
        self._buffers: dict[str, MeterGroupBuffer] = {}
        self._group_totals: dict[str, int] = {}
        self._space_to_group: dict[str, str] = {}
        self._last_snapshot_path: Optional[Path] = None
        self._loaded_at: Optional[dt.datetime] = None
        self._meter_root: Optional[Path] = None

    def load(self, model_path: Path, meter_root: Path, history_snapshots: int) -> None:
        # Load trained LightGBM meter model
        model_path = model_path.expanduser().resolve()
        if not model_path.exists():
            raise RuntimeError(f"Meter model file not found: {model_path}")
        booster = lgb.Booster(model_file=str(model_path))

        mroot = _resolve_meter_root(meter_root)
        occupancy_snaps = _list_meter_occupancy_snapshots(mroot)
        if not occupancy_snaps:
            raise RuntimeError(f"No meter occupancy snapshots found under {mroot}")

        space_to_group, group_totals = _load_meter_group_maps(mroot)
        recent = occupancy_snaps[-history_snapshots:]
        buffers: dict[str, MeterGroupBuffer] = {}

        for snap_path in recent:
            ts = _parse_ts(snap_path)
            if ts is None:
                continue
            group_vacant_counts: dict[str, int] = {}
            for row in _read_meter_csv(snap_path):
                parking_space_id = row.get("ParkingSpaceId", "").strip()
                if not parking_space_id:
                    continue
                group_key = space_to_group.get(parking_space_id)
                if not group_key:
                    continue
                if row.get("OccupancyStatus") == "V":
                    group_vacant_counts[group_key] = (
                        group_vacant_counts.get(group_key, 0) + 1
                    )

            for group_key, total_spaces in group_totals.items():
                value = float(group_vacant_counts.get(group_key, 0))
                buf = buffers.setdefault(group_key, MeterGroupBuffer())
                if buf.times and (ts - buf.times[-1]).total_seconds() / 60 > 90:
                    buf.values.clear()
                    buf.times.clear()
                buf.push(ts, min(value, float(total_spaces)))

        # Derive feature column order from a sample group
        dummy_buf = next(iter(buffers.values())) if buffers else MeterGroupBuffer()
        dummy_total = next(iter(group_totals.values())) if group_totals else 1
        dummy_feats = _make_meter_features(dt.datetime.now(), dummy_buf, dummy_total)
        feature_names = list(dummy_feats.keys())

        with self._lock:
            self._model = booster
            self._feature_names = feature_names
            self._buffers = buffers
            self._group_totals = group_totals
            self._space_to_group = space_to_group
            self._last_snapshot_path = occupancy_snaps[-1]
            self._loaded_at = dt.datetime.now(dt.timezone.utc)
            self._meter_root = mroot

        print(
            f"[vacancy_api] Meter model loaded: {len(buffers)} groups, "
            f"last snapshot={occupancy_snaps[-1].name}, "
            f"features={feature_names}",
            flush=True,
        )

    def refresh(self) -> int:
        with self._lock:
            if self._meter_root is None or self._last_snapshot_path is None:
                return 0
            all_snaps = _list_meter_occupancy_snapshots(self._meter_root)
            space_to_group = dict(self._space_to_group)
            group_totals = dict(self._group_totals)

        try:
            last_idx = all_snaps.index(self._last_snapshot_path)
            new_snaps = all_snaps[last_idx + 1 :]
        except ValueError:
            new_snaps = []

        if not new_snaps:
            return 0

        with self._lock:
            buffers_copy = dict(self._buffers)

        for snap_path in new_snaps:
            ts = _parse_ts(snap_path)
            if ts is None:
                continue
            group_vacant_counts: dict[str, int] = {}
            for row in _read_meter_csv(snap_path):
                parking_space_id = row.get("ParkingSpaceId", "").strip()
                if not parking_space_id:
                    continue
                group_key = space_to_group.get(parking_space_id)
                if not group_key:
                    continue
                if row.get("OccupancyStatus") == "V":
                    group_vacant_counts[group_key] = (
                        group_vacant_counts.get(group_key, 0) + 1
                    )

            for group_key, total_spaces in group_totals.items():
                value = float(group_vacant_counts.get(group_key, 0))
                buf = buffers_copy.setdefault(group_key, MeterGroupBuffer())
                if buf.times and (ts - buf.times[-1]).total_seconds() / 60 > 90:
                    buf.values.clear()
                    buf.times.clear()
                buf.push(ts, min(value, float(total_spaces)))

        with self._lock:
            self._buffers = buffers_copy
            self._last_snapshot_path = new_snaps[-1]

        return len(new_snaps)

    def predict(self, group_key: str) -> dict:
        with self._lock:
            model = self._model
            feature_names = list(self._feature_names)
            buf = self._buffers.get(group_key)
            total_spaces = self._group_totals.get(group_key, 0)
            loaded_at = self._loaded_at

        if model is None:
            raise RuntimeError("Meter model not loaded")
        if buf is None or len(buf.values) == 0:
            raise ValueError(f"No history for meter group={group_key!r}")
        if total_spaces <= 0:
            total_spaces = int(round(max(buf.values))) if buf.values else 1

        now = dt.datetime.now()
        lag_1 = float(buf.values[-1])
        current = int(round(lag_1))

        feats = _make_meter_features(now, buf, total_spaces)
        feat_row = np.array(
            [[feats.get(k, float("nan")) for k in feature_names]], dtype=np.float32
        )
        # Delta mode: model predicts (target − lag_1); add lag_1 back
        delta = float(model.predict(feat_row)[0])
        predicted = max(0.0, min(float(total_spaces), lag_1 + delta))

        confidence = "ok"
        if len(buf.values) < _METER_MAX_LAG:
            confidence = "low_history"
        elif buf.times and (now - buf.times[-1]).total_seconds() / 60 > 20:
            confidence = "stale"

        return {
            "group_key": group_key,
            "current_vacancy": current,
            "predicted_vacancy": int(round(predicted)),
            "total_spaces": total_spaces,
            "horizon_steps": _METER_HORIZON_STEPS,
            "horizon_minutes": _METER_HORIZON_STEPS * 5,
            "predicted_at": now.isoformat(),
            "confidence": confidence,
            "model_loaded_at": loaded_at.isoformat() if loaded_at else None,
        }


_meter_predictor = MeterVacancyPredictor()


# ---------------------------------------------------------------------------
# Background refresh thread
# ---------------------------------------------------------------------------

def _refresh_loop(interval_seconds: int = 600) -> None:
    import time
    while True:
        time.sleep(interval_seconds)
        try:
            n = _predictor.refresh()
            if n:
                print(f"[vacancy_api] Refreshed {n} new snapshot(s)", flush=True)
            meter_n = _meter_predictor.refresh()
            if meter_n:
                print(
                    f"[vacancy_api] Refreshed {meter_n} new meter snapshot(s)",
                    flush=True,
                )
        except Exception as exc:
            print(f"[vacancy_api] Refresh error: {exc}", flush=True)


# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------

app = FastAPI(title="Vacancy Prediction API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET"],
    allow_headers=["*"],
)


@app.on_event("startup")
def _startup() -> None:
    _predictor.load(
        model_path=_MODEL_PATH,
        vacancy_root=_GOV_VACANCY_ROOT,
        history_snapshots=_HISTORY_SNAPSHOTS,
    )
    _meter_predictor.load(
        model_path=_METER_MODEL_PATH,
        meter_root=_GOV_METERS_ROOT,
        history_snapshots=max(_HISTORY_SNAPSHOTS * 48, 576),
    )
    t = threading.Thread(target=_refresh_loop, daemon=True)
    t.start()


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/v1/predict")
def predict_vacancy(
    park_id: str = Query(..., description="Carpark park_Id, e.g. '27'"),
    vehicle_type: str = Query("privateCar", description="Vehicle type key"),
) -> dict:
    """Return the predicted vacancy ~1 hour ahead for a given carpark."""
    try:
        return _predictor.predict(park_id=park_id, vehicle_type=vehicle_type)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@app.get("/v1/parks")
def list_parks() -> dict:
    """List all park IDs that have history in the model."""
    with _predictor._lock:
        ids = sorted(_predictor._buffers.keys())
    return {"park_ids": ids, "count": len(ids)}


@app.get("/v1/predict-meter")
def predict_meter_vacancy(
    group_key: str = Query(..., description="Meter street group key"),
) -> dict:
    """Return the predicted vacant metered spaces ~1 hour ahead for a street group."""
    try:
        return _meter_predictor.predict(group_key=group_key)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@app.get("/v1/meter-groups")
def list_meter_groups() -> dict:
    """List all meter street-group keys that have history in the predictor."""
    with _meter_predictor._lock:
        keys = sorted(_meter_predictor._buffers.keys())
    return {"group_keys": keys, "count": len(keys)}
