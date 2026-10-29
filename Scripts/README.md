# Scripts

Tooling for Gjuha. Two groups: checks that CI runs on every push, and the content
pipeline that authors seed data offline.

Everything here is pure Python standard library on purpose, so the CI jobs that
run it need no dependency install.

---

## Checks (CI runs all four)

### `gen_colors.py`

The only writer of `Gjuha/Resources/Palette.xcassets`. Generates all 27 colour
tokens with four appearances each (light, dark, and the increased-contrast
variant of both), then measures the WCAG 2.1 contrast of every
foreground/background pair it ships and **exits non-zero if any falls below
4.5:1**.

```bash
python3 Scripts/gen_colors.py
```

CI runs it and fails if the result differs from what is committed, so the catalog
cannot be hand-edited in Xcode past the contrast floor. The other half of that
guarantee is `GjuhaContrastTests`, which measures the same pairs against the
colours the running app resolves. Both are needed: this script cannot see what
the app renders, and the test cannot see the generator.

To add or change a colour, edit the `COLORS` table here and re-run. Never edit
the catalog directly.

### `validate_seed.py`

Decodes every bundled seed file and resolves its cross-references. The app decodes
seed content with `try?` at runtime, so without this a typo degrades silently
instead of failing loudly.

```bash
python3 Scripts/validate_seed.py
```

### `check_localization.py`

Compares the keys the Swift compiler extracted during a build against the
committed String Catalogs. A key in the code but not the catalog ships
untranslated, which is an error; a key in the catalog but not the code is dead
weight, reported as a warning. Also reports how many Albanian entries are still
`needs_review`, which is informational and never fails the build.

Needs a prior build, because it reads the `.stringsdata` the compiler writes.

```bash
xcodebuild build -project Gjuha.xcodeproj -scheme Gjuha \
  -destination 'platform=iOS Simulator,name=iPhone 17' -skipMacroValidation
python3 Scripts/check_localization.py
```

If it reports a key you have already renamed, the build was incremental and did
not recompile that file. Delete the stale extraction and build again:

```bash
find ~/Library/Developer/Xcode/DerivedData -path "*Gjuha.build*" -name "*.stringsdata" -delete
```

### `ci/pick_simulator.py`

Prints the udid of a usable iOS simulator, read from `simctl` at run time. CI
runner images change their simulator line-up between releases, so hardcoding a
device name breaks the workflow for a reason that has nothing to do with the app.

```bash
xcrun simctl list devices available --json | python3 Scripts/ci/pick_simulator.py
```

---

## Content pipeline

Authoring tools, not part of the build. Their output is an input to hand curation,
not a bundled resource: nothing in the app bundle is allowed to sit there unread,
which is why earlier copies live in `Content/archive/`.

### `tools/fetch_sources.sh`

Pulls raw language data from open datasets (Tatoeba for the sentence corpus,
Wiktionary for morphology, Leipzig Corpora optionally for frequency). About
1.8 GB. Raw files are not committed.

### `tools/build_from_sources.py`

Processes the raw data into a frequency list and a sentence corpus, normalising
Unicode (ë, ç) along the way. Writes to `Scripts/content/generated/`.

### `tools/generate_audio.py`

Synthesizes per-word pronunciation audio, caches by content hash, and records
provenance in the audio manifest. Two backends:

- `apple-say` is free and offline, and there is **no Albanian voice**, so it
  mispronounces Albanian. Development only.
- `azure` uses Neural TTS `sq-AL-AnilaNeural`. It needs `AZURE_SPEECH_KEY` and
  `AZURE_SPEECH_REGION` in the environment plus an explicit `--yes-incur-cost`
  flag, so it cannot bill anyone by accident.

It never marks an asset `reviewed: true`. That is a deliberate human step after
native-speaker review, which is why the app still ships zero reviewed clips. See
`Documentation/Content/AUDIO_PIPELINE.md`.

```bash
bash Scripts/tools/fetch_sources.sh
python3 Scripts/tools/build_from_sources.py
```

---

## Notes

- Raw dataset files are **not committed**: too large, and regeneratable.
- Only processed, validated JSON seed files are committed.
- The pipeline is deterministic: the same source data gives the same output.
