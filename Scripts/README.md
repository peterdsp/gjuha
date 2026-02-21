# Scripts

Build and data tooling for the Gjuha content pipeline.

---

## Content Pipeline (planned)

### `fetch_sources.sh`
Pulls raw language data from open datasets:
- **Tatoeba** — Albanian sentence corpus
- **Wiktionary** — Albanian word entries with morphological data
- **Leipzig Corpora** (optional) — frequency data

### `build_from_sources.py`
Processes raw data into structured Gjuha seed files:
- Generates top-6000 word frequency list
- Outputs 50k Albanian sentence CSV
- Validates and normalizes Unicode (ë, ç, etc.)
- Maps vocabulary to CEFR levels

### Output
```
Scripts/output/
├── word_frequency_6000.json     → feeds Data/Seed/Vocabulary/
├── sentences_50k.csv            → feeds exercise generator
└── build_report.txt             → stats and validation errors
```

---

## Usage (when implemented)

```bash
# Pull open datasets
./Scripts/tools/fetch_sources.sh

# Generate seed data
python3 ./Scripts/tools/build_from_sources.py

# Output lands in Data/Seed/
```

---

## Notes

- Raw dataset files are **not committed** to the repo (too large, regeneratable)
- Only the processed, validated JSON seed files are committed
- The build pipeline is deterministic — same source data = same output
