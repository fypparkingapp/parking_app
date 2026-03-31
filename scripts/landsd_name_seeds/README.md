# LandsD Name Seeds

This folder stores plain-text seed lists that feed the LandsD batch import flow.

Suggested phase-1 targets for a more complete search dataset:

- `housing_estates.txt`: `2,000`
- `malls.txt`: `1,200`
- `office_towers.txt`: `1,500`
- `schools.txt` + `hospitals.txt` + `government_offices.txt`: `1,200`
- `hotels.txt` + `theme_parks.txt` + `arts_venues.txt` + `major_destinations.txt`: `800`

Recommended workflow:

1. Add or harvest raw names into `major_destinations_1000.txt`.
2. Run `scripts/classify_landsd_name_seeds.py` to split names into category files.
3. Review the generated files and move obvious mistakes manually.
4. Run `scripts/generate_landsd_batch_csv.py --names-dir ...` to create one or more staged batch CSV files.
5. Import each batch with `scripts/landsd_location_capture.py --batch-file ...`.

Suggested 10k-scale batch strategy:

1. Phase 1: high-signal places first.
   Focus on `officeTower`, `mall`, `hospital`, `hotel`, `governmentOffice`.
   Example:
   `python3 scripts/generate_landsd_batch_csv.py --names-dir scripts/landsd_name_seeds --output tmp/landsd_phase1.csv --split-size 400 --subcategory-limit officeTower=1500 --subcategory-limit mall=1200 --subcategory-limit hospital=300 --subcategory-limit hotel=400 --subcategory-limit governmentOffice=500`
2. Phase 2: education and curated destinations.
   Add `school`, `campus`, `artsVenue`, `themePark`, `majorDestination`.
   Example:
   `python3 scripts/generate_landsd_batch_csv.py --names-dir scripts/landsd_name_seeds --output tmp/landsd_phase2.csv --split-size 400 --subcategory-order school,campus,artsVenue,themePark,majorDestination,officeTower,mall,hospital,hotel,governmentOffice,industrialArea,housingEstate --subcategory-limit school=800 --subcategory-limit campus=200 --subcategory-limit artsVenue=300 --subcategory-limit themePark=80 --subcategory-limit majorDestination=1500`
3. Phase 3: long-tail and noisy categories last.
   Leave `housingEstate` and broad `majorDestination` expansion to the end because they generate the most ambiguous hits.
   Example:
   `python3 scripts/generate_landsd_batch_csv.py --names-dir scripts/landsd_name_seeds --output tmp/landsd_phase3.csv --split-size 250 --subcategory-order housingEstate,majorDestination,industrialArea,officeTower,mall,hospital,hotel,governmentOffice,school,campus,artsVenue,themePark --subcategory-limit housingEstate=4000 --subcategory-limit majorDestination=2500 --subcategory-limit industrialArea=500`

Operational tips:

- Keep shard size between `250` and `500` rows so failures are easy to retry.
- Always pass `--summary-json` when generating staged CSVs so you can track category growth.
- Add `--skip-existing` so staged batches do not re-enqueue places already present in `assets/data/local_landmarks/*.json`.
- Import with `--batch-sleep-ms 250` or higher to stay gentle with LandsD.
- Review `writtenFiles` and per-row failures after each import before moving to the next shard.
- Treat `housingEstate` as a coverage bucket, not a quality bucket; expect more false positives there.

Notes:

- The classifier is heuristic only; expect false positives.
- `major_destinations.txt` is the fallback bucket for anything not confidently classified.
