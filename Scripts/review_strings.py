#!/usr/bin/env python3
"""Takes the Albanian review out of Xcode and puts it in a spreadsheet.

The release is gated on a native Albanian speaker reading the interface, and
until now the only way in was Xcode on a Mac. A reviewer who speaks Albanian is
not necessarily a developer, and asking them to install 10 GB of developer
tools to read 227 sentences is a good way for the review never to happen.

    python3 Scripts/review_strings.py export            # write the CSV
    python3 Scripts/review_strings.py import            # read it back
    python3 Scripts/review_strings.py import --dry-run  # say what would change

The CSV opens in Numbers, Excel or Google Sheets. The reviewer edits the
`albanian` column and writes `ok` in `approved` for each line they are happy
with. Nothing is marked reviewed without that word: a filled-in translation
with an empty `approved` stays pending, so a half finished pass cannot look
complete.

Plural forms are exported one row per category, because Albanian may need a
different word for one and for many, and a single row would hide that.
"""
import argparse
import csv
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOGS = {
    "app": ROOT / "Gjuha/Resources/Localizable.xcstrings",
    "widget": ROOT / "GjuhaWidgets/Localizable.xcstrings",
}
CSV_PATH = ROOT / "Documentation/Release/albanian-review.csv"
PENDING = ("needs_review", "new")
COLUMNS = ["catalog", "key", "variation", "english", "albanian", "state", "approved", "note"]


def units_of(localization):
    """Every translatable unit in a localization, with the path that locates it.

    A string is usually one unit. A plural is one per category, and a
    substitution is one per category of its own nested plural.
    """
    if localization.get("stringUnit"):
        yield ("", localization["stringUnit"])
    plural = (localization.get("variations") or {}).get("plural") or {}
    for category, value in plural.items():
        if value.get("stringUnit"):
            yield (f"plural.{category}", value["stringUnit"])
    for name, sub in (localization.get("substitutions") or {}).items():
        sub_plural = (sub.get("variations") or {}).get("plural") or {}
        for category, value in sub_plural.items():
            if value.get("stringUnit"):
                yield (f"substitution.{name}.plural.{category}", value["stringUnit"])


def english_for(entry, variation):
    """The source text for a row, falling back to the key itself."""
    english = (entry.get("localizations") or {}).get("en") or {}
    for path, unit in units_of(english):
        if path == variation:
            return unit.get("value", "")
    for _, unit in units_of(english):
        if unit.get("value"):
            return unit["value"]
    return ""


def rows_awaiting_review():
    for name, path in CATALOGS.items():
        catalog = json.loads(path.read_text())
        for key, entry in sorted(catalog.get("strings", {}).items()):
            albanian = (entry.get("localizations") or {}).get("sq") or {}
            for variation, unit in units_of(albanian):
                if unit.get("state") not in PENDING:
                    continue
                yield {
                    "catalog": name,
                    "key": key,
                    "variation": variation,
                    "english": english_for(entry, variation) or key,
                    "albanian": unit.get("value", ""),
                    "state": unit.get("state", ""),
                    "approved": "",
                    "note": "no translation yet" if unit.get("state") == "new" else "",
                }


def do_export():
    rows = list(rows_awaiting_review())
    CSV_PATH.parent.mkdir(parents=True, exist_ok=True)
    with CSV_PATH.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=COLUMNS)
        writer.writeheader()
        writer.writerows(rows)
    untranslated = sum(1 for r in rows if r["state"] == "new")
    print(f"Wrote {len(rows)} rows to {CSV_PATH.relative_to(ROOT)}")
    print(f"  {len(rows) - untranslated} have an Albanian draft to check")
    print(f"  {untranslated} have no Albanian at all and need writing")
    print("\nThe reviewer edits `albanian` and writes ok in `approved`.")
    return 0


def unit_at(entry, variation):
    """The Albanian unit a row refers to, or None if the shape changed."""
    albanian = (entry.get("localizations") or {}).get("sq") or {}
    for path, unit in units_of(albanian):
        if path == variation:
            return unit
    return None


def do_import(dry_run):
    if not CSV_PATH.exists():
        print(f"No {CSV_PATH.relative_to(ROOT)}. Run the export first.")
        return 1

    with CSV_PATH.open(encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    approved = [r for r in rows if (r.get("approved") or "").strip().lower() == "ok"]
    blank = [r for r in approved if not (r.get("albanian") or "").strip()]
    if blank:
        print(f"{len(blank)} row(s) are approved with no Albanian. Nothing was written:")
        for row in blank[:10]:
            print(f"  {row['catalog']}: {row['key']!r}")
        return 1

    changed, missing = 0, []
    catalogs = {name: json.loads(path.read_text()) for name, path in CATALOGS.items()}
    for row in approved:
        catalog = catalogs.get(row["catalog"])
        entry = (catalog or {}).get("strings", {}).get(row["key"])
        if entry is None:
            missing.append(row["key"])
            continue
        unit = unit_at(entry, row["variation"])
        if unit is None:
            missing.append(f"{row['key']} [{row['variation']}]")
            continue
        unit["value"] = row["albanian"].strip()
        unit["state"] = "translated"
        changed += 1

    if missing:
        print(f"{len(missing)} approved row(s) no longer match the catalog:")
        for key in missing[:10]:
            print(f"  {key!r}")
        print("The code moved on since the export. Re-export and merge by hand.")
        return 1

    pending = len(rows) - len(approved)
    if dry_run:
        print(f"Would mark {changed} string(s) reviewed, leaving {pending} pending.")
        return 0

    for name, path in CATALOGS.items():
        path.write_text(json.dumps(catalogs[name], ensure_ascii=False, indent=2) + "\n")
    print(f"Marked {changed} string(s) reviewed, {pending} still pending.")
    print("Re-run Scripts/sync_android_strings.py so Android picks the corrections up.")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["export", "import"])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    return do_export() if args.action == "export" else do_import(args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
