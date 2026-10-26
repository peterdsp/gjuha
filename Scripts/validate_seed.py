#!/usr/bin/env python3
"""Validate the seed content that ships inside the app bundle.

Why this exists: every seed file is decoded with `try?` at runtime, so a typo
degrades silently. `LiveCurriculumRepository`, for instance, falls back to a
three-lesson mock curriculum if `units.json` or `lessons.json` fails to decode,
which looks like "the app only has three lessons" rather than like an error. This
script turns every such silent degradation into a failed build.

It checks three things:

1. Shape. Every required field the Swift decoders declare is present and the
   right type. The field names here mirror `SeedUnit`, `SeedLesson`,
   `SeedWordJSON`, `SeedGrammarTopic`, and `AudioManifest`.
2. Enum membership. Values that decode into a Swift enum (`CEFRLevel`,
   `PartOfSpeech`, `NounGender`, `VerbClass`, `GrammarCategory`) are rejected if
   they are not a case, because an unknown case decodes to nil or a default.
3. Referential integrity. Lesson unlock prerequisites, grammar ids, and audio
   manifest word ids all resolve to something that exists.

Run: python3 Scripts/validate_seed.py
Exit status is non-zero if anything fails, so CI stops.

Note: `Documentation/Content/*.schema.json` describes the *authoring pipeline*
format (snake_case, `base_form`, `cefr: "A1"`), which is a different shape from
the runtime seed. This script validates the runtime shape, because that is what
the app decodes.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEED = ROOT / "Gjuha" / "Data" / "Seed"

# Mirrors of the Swift enums. Keep in step with Data/Models.
CEFR_RUNTIME = {"a1", "a2", "b1", "b2", "c1", "c2"}          # CEFRLevel raw values
CEFR_SEED = {"A1", "A2", "B1", "B2", "C1", "C2"}             # as written in units/lessons
PART_OF_SPEECH = {
    "noun", "verb", "adjective", "adverb", "pronoun",
    "preposition", "conjunction", "interjection", "numeral", "particle",
}
GENDER = {"m", "f", "n"}
VERB_CLASS = {"firstConjugation", "secondConjugation", "thirdConjugation", "irregular"}
GRAMMAR_CATEGORY = {
    "nouns", "verbs", "adjectives", "pronouns", "numbers",
    "cases", "wordOrder", "negation", "questions",
}

errors: list[str] = []
warnings: list[str] = []


def fail(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def load(path: Path):
    if not path.exists():
        fail(f"{path.relative_to(ROOT)}: missing, but the app expects to decode it")
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"{path.relative_to(ROOT)}: invalid JSON ({exc})")
        return None


def require(obj, field, kind, where):
    """Check a required field exists with the right type."""
    if field not in obj or obj[field] is None:
        fail(f"{where}: missing required field '{field}'")
        return None
    value = obj[field]
    if not isinstance(value, kind):
        fail(f"{where}: '{field}' should be {kind.__name__}, got {type(value).__name__}")
        return None
    if kind is str and not value.strip():
        fail(f"{where}: '{field}' is empty")
        return None
    return value


def optional(obj, field, kind, where):
    value = obj.get(field)
    if value is None:
        return None
    if not isinstance(value, kind):
        fail(f"{where}: optional '{field}' should be {kind.__name__}, got {type(value).__name__}")
        return None
    return value


# ---------------------------------------------------------------- vocabulary

vocab = load(SEED / "Vocabulary" / "a1_vocabulary.json")
word_ids: set[str] = set()

if vocab is not None:
    if not isinstance(vocab, list):
        fail("a1_vocabulary.json: expected a top-level array")
    else:
        for i, w in enumerate(vocab):
            where = f"a1_vocabulary.json[{i}]"
            if not isinstance(w, dict):
                fail(f"{where}: expected an object")
                continue
            wid = require(w, "id", str, where)
            require(w, "albanian", str, where)
            require(w, "english", str, where)
            level = require(w, "cefrLevel", str, where)
            pos = require(w, "partOfSpeech", str, where)

            if wid:
                if wid in word_ids:
                    fail(f"{where}: duplicate word id '{wid}'")
                word_ids.add(wid)
            if level and level not in CEFR_RUNTIME:
                fail(f"{where}: cefrLevel '{level}' is not a CEFRLevel case {sorted(CEFR_RUNTIME)}")
            if pos and pos not in PART_OF_SPEECH:
                fail(f"{where}: partOfSpeech '{pos}' is not a PartOfSpeech case")

            gender = optional(w, "gender", str, where)
            if gender is not None and gender not in GENDER:
                fail(f"{where}: gender '{gender}' is not a NounGender raw value {sorted(GENDER)}")
            vclass = optional(w, "verbClass", str, where)
            if vclass is not None and vclass not in VERB_CLASS:
                fail(f"{where}: verbClass '{vclass}' is not a VerbClass case")
            optional(w, "exampleSentence", str, where)
            optional(w, "exampleTranslation", str, where)
            optional(w, "audioFileName", str, where)
            optional(w, "frequency", int, where)

            # Not fatal, but worth surfacing: the engine needs an example
            # sentence to build a cloze question for a word.
            if pos == "noun" and gender is None:
                warn(f"{where}: noun '{wid}' has no gender, so gender drills cannot use it")
            if pos == "verb" and vclass is None:
                warn(f"{where}: verb '{wid}' has no verbClass")

# ---------------------------------------------------------------- units

units = load(SEED / "units.json")
unit_numbers: set[int] = set()

if units is not None:
    if not isinstance(units, list) or not units:
        fail("units.json: expected a non-empty top-level array")
    else:
        for i, u in enumerate(units):
            where = f"units.json[{i}]"
            if not isinstance(u, dict):
                fail(f"{where}: expected an object")
                continue
            number = require(u, "unit", int, where)
            require(u, "title", str, where)
            cefr = require(u, "cefr", str, where)
            themes = require(u, "themes", list, where)

            if number is not None:
                if number in unit_numbers:
                    fail(f"{where}: duplicate unit number {number}")
                unit_numbers.add(number)
            if cefr and cefr not in CEFR_SEED:
                fail(f"{where}: cefr '{cefr}' is not one of {sorted(CEFR_SEED)}")
            if themes is not None and not all(isinstance(t, str) and t.strip() for t in themes):
                fail(f"{where}: 'themes' must be non-empty strings")

# ---------------------------------------------------------------- lessons

lessons = load(SEED / "lessons.json")
lesson_ids: set[str] = set()
lesson_rows: list[dict] = []

if lessons is not None:
    if not isinstance(lessons, list) or not lessons:
        fail("lessons.json: expected a non-empty top-level array")
    else:
        for i, l in enumerate(lessons):
            where = f"lessons.json[{i}]"
            if not isinstance(l, dict):
                fail(f"{where}: expected an object")
                continue
            lid = require(l, "id", str, where)
            unit = require(l, "unit", int, where)
            require(l, "order", int, where)
            require(l, "title", str, where)
            cefr = require(l, "cefr", str, where)
            objectives = require(l, "objectives", list, where)
            unlock = require(l, "unlock", dict, where)
            plan = optional(l, "exercise_plan", list, where)

            if lid:
                if lid in lesson_ids:
                    fail(f"{where}: duplicate lesson id '{lid}'")
                lesson_ids.add(lid)
            if cefr and cefr not in CEFR_SEED:
                fail(f"{where}: cefr '{cefr}' is not one of {sorted(CEFR_SEED)}")
            if objectives is not None and not all(isinstance(o, str) and o.strip() for o in objectives):
                fail(f"{where}: 'objectives' must be non-empty strings")
            if plan is not None and not all(isinstance(p, str) and p.strip() for p in plan):
                fail(f"{where}: 'exercise_plan' must be non-empty strings")
            if unlock is not None:
                reqs = unlock.get("requires_lesson_ids")
                if not isinstance(reqs, list):
                    fail(f"{where}: unlock.requires_lesson_ids must be an array")
                elif not all(isinstance(r, str) for r in reqs):
                    fail(f"{where}: unlock.requires_lesson_ids must contain strings")
            if unit is not None and unit_numbers and unit not in unit_numbers:
                fail(f"{where}: unit {unit} has no matching entry in units.json")
            lesson_rows.append(l)

        # Unlock prerequisites must resolve, or a lesson is permanently locked.
        for l in lesson_rows:
            unlock = l.get("unlock") or {}
            for req in (unlock.get("requires_lesson_ids") or []):
                if req not in lesson_ids:
                    fail(f"lessons.json: lesson '{l.get('id')}' requires unknown lesson '{req}'")
                if req == l.get("id"):
                    fail(f"lessons.json: lesson '{l.get('id')}' lists itself as a prerequisite")

        # Within a unit, order values must be unique so the map is deterministic.
        by_unit: dict[int, list[int]] = {}
        for l in lesson_rows:
            if isinstance(l.get("unit"), int) and isinstance(l.get("order"), int):
                by_unit.setdefault(l["unit"], []).append(l["order"])
        for unit, orders in sorted(by_unit.items()):
            if len(orders) != len(set(orders)):
                fail(f"lessons.json: unit {unit} has duplicate 'order' values {sorted(orders)}")

        # At least one lesson must be openable on a fresh install, or the app
        # presents a fully locked map.
        if lesson_rows and not any(
            not (l.get("unlock") or {}).get("requires_lesson_ids") for l in lesson_rows
        ):
            fail("lessons.json: no lesson is unlocked on a fresh install")

# ---------------------------------------------------------------- grammar

grammar = load(SEED / "Grammar" / "a1_grammar.json")
grammar_ids: set[str] = set()

if grammar is not None:
    if not isinstance(grammar, list):
        fail("a1_grammar.json: expected a top-level array")
    else:
        for i, g in enumerate(grammar):
            where = f"a1_grammar.json[{i}]"
            if not isinstance(g, dict):
                fail(f"{where}: expected an object")
                continue
            gid = require(g, "id", str, where)
            require(g, "title", str, where)
            require(g, "subtitle", str, where)
            level = require(g, "cefrLevel", str, where)
            category = require(g, "category", str, where)
            require(g, "explanation", str, where)
            table = require(g, "conjugationTable", list, where)
            examples = require(g, "examples", list, where)

            if gid:
                if gid in grammar_ids:
                    fail(f"{where}: duplicate grammar id '{gid}'")
                grammar_ids.add(gid)
            if level and level not in CEFR_RUNTIME:
                fail(f"{where}: cefrLevel '{level}' is not a CEFRLevel case")
            if category and category not in GRAMMAR_CATEGORY:
                fail(f"{where}: category '{category}' is not a GrammarCategory case")
            if table is not None:
                for r, row in enumerate(table):
                    if not isinstance(row, list) or not all(isinstance(c, str) for c in row):
                        fail(f"{where}: conjugationTable[{r}] must be an array of strings")
                widths = {len(row) for row in table if isinstance(row, list)}
                if len(widths) > 1:
                    fail(f"{where}: conjugationTable rows have differing widths {sorted(widths)}")
            if examples is not None and not all(isinstance(e, str) and e.strip() for e in examples):
                fail(f"{where}: 'examples' must be non-empty strings")

# ---------------------------------------------------------------- audio manifest

manifest = load(SEED / "audio_manifest.json")

if manifest is not None:
    where = "audio_manifest.json"
    if not isinstance(manifest, dict):
        fail(f"{where}: expected an object")
    else:
        require(manifest, "version", str, where)
        assets = require(manifest, "assets", list, where)
        if assets:
            for i, a in enumerate(assets):
                aw = f"{where}.assets[{i}]"
                if not isinstance(a, dict):
                    fail(f"{aw}: expected an object")
                    continue
                wid = require(a, "wordId", str, aw)
                require(a, "text", str, aw)
                filename = require(a, "file", str, aw)
                require(a, "provider", str, aw)
                reviewed = a.get("reviewed")
                if not isinstance(reviewed, bool):
                    fail(f"{aw}: 'reviewed' must be a boolean, so an unreviewed clip can never pass as approved")
                if wid and word_ids and wid not in word_ids:
                    fail(f"{aw}: wordId '{wid}' is not in the vocabulary")
                # A manifest entry whose file is absent is allowed by design
                # (the loader treats it as unavailable), but a reviewed entry
                # with no file is a contradiction worth catching.
                if reviewed is True and filename:
                    audio_dir = ROOT / "Gjuha" / "Resources" / "Audio"
                    if not (audio_dir / filename).exists():
                        fail(f"{aw}: marked reviewed:true but '{filename}' is not in Resources/Audio")

# ---------------------------------------------------------------- report

if warnings:
    print(f"{len(warnings)} warning(s):")
    for w in warnings[:25]:
        print(f"  warning: {w}")
    if len(warnings) > 25:
        print(f"  ... and {len(warnings) - 25} more")
    print()

if errors:
    print(f"FAILED: {len(errors)} error(s) in the seed content:")
    for e in errors:
        print(f"  error: {e}")
    sys.exit(1)

print(
    "Seed content OK: "
    f"{len(unit_numbers)} units, {len(lesson_ids)} lessons, "
    f"{len(word_ids)} vocabulary entries, {len(grammar_ids)} grammar topics."
)
