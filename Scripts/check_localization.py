#!/usr/bin/env python3
"""Fail if any user-facing string is missing from the String Catalogs.

Gjuha's interface is localized into Albanian, and the failure mode that matters is
quiet: someone adds a `Text("Save")`, nobody adds it to the catalog, and Albanian
speakers get one English word in the middle of a translated screen. Nothing in the
build complains, because an untranslated key falls back to the source language.

This closes that gap by comparing two sources of truth:

- What the Swift compiler extracted, from the `*.stringsdata` files it writes
  during a build (`SWIFT_EMIT_LOC_STRINGS` is on for both shipping targets).
- What the committed String Catalogs contain.

A key in the first set but not the second is a string that will silently ship
untranslated, and is an error. A key in the catalog but no longer in the code is
dead weight, reported as a warning rather than an error, because a string can
legitimately be extracted from only one build configuration.

It also reports how many Albanian entries still need a native speaker, counting
both `needs_review` (a machine-assisted translation nobody has read) and `new`
(a key with no translation at all). That is the gate described in
Documentation/Release/REVIEW_PACKAGE.md. The count is informational: it never
fails the build, because shipping with it non-zero is a recorded, deliberate
decision, not an accident.

Requires a prior build. Run:
    xcodebuild build -project Gjuha.xcodeproj -scheme Gjuha \\
        -destination 'platform=iOS Simulator,name=iPhone 17' -skipMacroValidation
    python3 Scripts/check_localization.py
"""
from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOGS = {
    "app": ROOT / "Gjuha" / "Resources" / "Localizable.xcstrings",
    "widget": ROOT / "GjuhaWidgets" / "Localizable.xcstrings",
}
DERIVED = Path.home() / "Library" / "Developer" / "Xcode" / "DerivedData"


def extracted_keys() -> dict[str, set[str]]:
    """Keys the compiler found, per target."""
    roots = sorted(DERIVED.glob("Gjuha-*/Build/Intermediates.noindex/Gjuha.build"))
    if not roots:
        sys.exit(
            "No Gjuha build intermediates found. Build the app first, so the\n"
            "compiler writes the .stringsdata files this check compares against."
        )
    found: dict[str, set[str]] = defaultdict(set)
    for root in roots:
        for f in root.rglob("*.stringsdata"):
            path = str(f)
            # The test bundles are not shipped and are not localized.
            if "/GjuhaTests.build/" in path or "/GjuhaUITests.build/" in path:
                continue
            target = "widget" if "/GjuhaWidgets.build/" in path else "app"
            try:
                data = json.loads(f.read_text())
            except (OSError, json.JSONDecodeError):
                continue
            for table, entries in (data.get("tables") or {}).items():
                # The AppShortcuts table is generated metadata, localized through
                # the same catalog via its own keys.
                if table != "Localizable":
                    continue
                for entry in entries:
                    key = entry.get("key")
                    if key:
                        found[target].add(key)
    return found


def catalog_keys(path: Path) -> tuple[set[str], int]:
    if not path.exists():
        sys.exit(f"Missing String Catalog: {path.relative_to(ROOT)}")
    data = json.loads(path.read_text())
    strings = data.get("strings") or {}
    needs_review = 0
    for entry in strings.values():
        for loc in (entry.get("localizations") or {}).values():
            units = [loc.get("stringUnit")] if loc.get("stringUnit") else []
            plural = ((loc.get("variations") or {}).get("plural") or {})
            units += [v.get("stringUnit") for v in plural.values()]
            for sub in (loc.get("substitutions") or {}).values():
                sub_plural = ((sub.get("variations") or {}).get("plural") or {})
                units += [v.get("stringUnit") for v in sub_plural.values()]
            # "needs_review" is a machine-assisted translation nobody has read.
            # "new" is a string with no translation at all, which Xcode marks
            # when a key is added. Both are work for the same reviewer, so both
            # are counted: reporting only the first understates the job, and
            # the number is the whole point of reporting it.
            if any(u and u.get("state") in ("needs_review", "new") for u in units):
                needs_review += 1
                break
    return set(strings), needs_review


def main() -> int:
    found = extracted_keys()
    errors: list[str] = []
    warnings: list[str] = []
    summary: list[str] = []

    for target, path in CATALOGS.items():
        in_catalog, needs_review = catalog_keys(path)
        in_code = found.get(target, set())

        for key in sorted(in_code - in_catalog):
            errors.append(
                f"[{target}] {key!r} is in the code but not in "
                f"{path.relative_to(ROOT)}, so it would ship untranslated."
            )
        for key in sorted(in_catalog - in_code):
            warnings.append(f"[{target}] {key!r} is in the catalog but no longer in the code.")

        summary.append(
            f"{target}: {len(in_catalog)} keys, {needs_review} awaiting native review"
        )

    if warnings:
        print(f"{len(warnings)} unused catalog key(s):")
        for w in warnings:
            print(f"  warning: {w}")
        print()

    if errors:
        print(f"FAILED: {len(errors)} untranslated string(s):")
        for e in errors:
            print(f"  error: {e}")
        print()
        print("Add each key to the String Catalog with an Albanian translation.")
        return 1

    print("Localization OK. " + "; ".join(summary) + ".")
    return 0


if __name__ == "__main__":
    sys.exit(main())
