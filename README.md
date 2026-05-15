# parking_app

Hong Kong parking assistant — a Flutter client that surfaces real-time carpark vacancy, metered street parking, and turn-by-turn navigation, backed by a custom self-hosted services stack and HK government open data.

## Features

- Real-time carpark vacancy (government + metered street parking)
- Short-term vacancy prediction via a LightGBM model
- Multilingual carpark search (English / Traditional / Simplified Chinese)
- Turn-by-turn navigation with toll fee estimates and live road-speed overlay
- Map themes (Default / Night Drive / Clean Atlas)

## Architecture

```
┌─────────────────────────┐
│   Flutter app (this)    │
└────────────┬────────────┘
             │
   ┌─────────┴──────────────────────────┐
   ▼                                    ▼
Self-hosted backends                 HK Gov open data
(parking_app_backend repo)           (api.data.gov.hk,
                                      resource.data.one.gov.hk,
- parking_api    :8000                map.gov.hk,
- vacancy_api    :8081                hkemobility.gov.hk)
- osrm           :8082
- data_harvester (cron)
```

All endpoint URLs are centralized in [`lib/config/api_config.dart`](lib/config/api_config.dart). Flip `useLocalBackends` to `true` to point the three self-hosted services at a local Docker stack instead of the deployed `*.ryanpumpkin.com` instances.

## Backend repo

The four self-hosted services live in a separate repository:
👉 **https://github.com/fypparkingapp/parking_app_backend**

| Service | Purpose | Port |
| --- | --- | --- |
| `parking_api` | Carpark info + photos (FastAPI) | 8000 |
| `vacancy_api` | LightGBM vacancy prediction (FastAPI) | 8081 |
| `osrm` | Routing with live-speed updates | 8082 |
| `data_harvester` | Periodic gov CSV snapshot worker | — |

## Run

```bash
flutter pub get
flutter run -d <device>
```

To run against a local backend stack, clone `parking_app_backend` and `docker compose up` each service, then set `useLocalBackends = true` in `lib/config/api_config.dart`.

## Vacancy training

The training scripts that produce the LightGBM model used by `vacancy_api` live in [`scripts/`](scripts/). Example:

```bash
python3 scripts/train_gov_vacancy_baseline.py \
  --data-root ./gov_vacancy \
  --report-out tmp/vacancy_report.json \
  --model-out tmp/vacancy_model.json
```

Useful options:

- `--park-id 27 --park-id 30`: train and inspect only specific carparks
- `--max-files 2000`: quick smoke test on a smaller subset
- `--sample-every 3`: downsample snapshots for faster experiments
- `--horizon-steps 6`: predict about 1 hour ahead when the feed is ~10 min cadence
- `--train-ratio 1.0`: train on all files and skip holdout evaluation
