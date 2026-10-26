# Archived content files

These files used to sit under `Gjuha/Data/Seed/`, which is inside the app target's
source root, so every one of them was copied into the shipped app bundle. Nothing
reads them: no Swift file references them, and the content pipeline in
`Scripts/tools/` does not read them either (it writes its own outputs to
`Scripts/content/generated/`). They were dead weight in the bundle, and
`a1_lessons.json` was actively misleading because it looks like the curriculum
while the real curriculum is `Gjuha/Data/Seed/units.json` plus `lessons.json`.

They are kept here rather than deleted, because they are real work and some are
useful inputs for regenerating content later.

| File | What it is | Why it is not in the app |
|---|---|---|
| `sentences_sqi_50k.csv` | 50k Albanian sentences extracted from Tatoeba (`sqi`) by `Scripts/tools/build_from_sources.py` | Pipeline artifact. The app never reads sentences from CSV; exercises come from `a1_vocabulary.json` plus the engine. |
| `word_frequency_top6000.csv` | Frequency-ranked word list built from those sentences | Pipeline artifact used to prioritise vocabulary during authoring, not at runtime. |
| `morph_rules.json` | Early sketch of morphology rules | Never wired up. `Documentation/Content/morph_rules.schema.json` still documents the intended shape. |
| `exercise_types.json` | Early sketch of the exercise type catalogue | Superseded by the `ExerciseType` enum and the per-lesson `exercise_plan` in `lessons.json`. |
| `a1_lessons.json` | An early 7-lesson, 2-unit curriculum in a different shape than the runtime loader expects | Superseded by `units.json` (12 units) plus `lessons.json` (120 lessons), which is what `LiveCurriculumRepository` actually decodes. |

If any of these is ever needed at runtime again, move it back under
`Gjuha/Data/Seed/` and add the loader in the same commit, so a bundled file always
has a reader.
