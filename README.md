# parking_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Vacancy Training

You can train a lightweight next-snapshot vacancy baseline from mirrored
government history with:

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
