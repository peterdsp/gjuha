# Quarantined content pipeline artifacts

These files were bundled into the app but are placeholder-only or unused. They
are moved out of the app target here to keep provenance without shipping fake or
misleading content. None were referenced by app code at the time of removal
(Phase 1). Regenerate real versions with `Scripts/tools/build_from_sources.py`.

- `vocabulary_seed_600.csv` - 600 rows, of which only 30 (V0001-V0030) were real
  curated words; the remaining 570 were `__TODO_WORD_NNNN__` / `__TODO__`
  placeholders. It was loaded by `LiveVocabularyRepository` and surfaced those
  placeholders (and 26 duplicates of the canonical JSON) in the vocabulary
  browser. The canonical source is now `Gjuha/Data/Seed/Vocabulary/a1_vocabulary.json`;
  the 4 real curated words it did not already contain (je, është, përshëndetje,
  të lutem) were merged into that JSON as w351-w354.
- `exercises_seed_1000.json` - 1000 auto-generated placeholder exercises, every
  one carrying the note "Replace with real generated content from templates +
  vocab" (2 distinct prompts total). Never loaded at runtime.
- `sentence_templates_300.json` - 300 entries that are all the same template
  string `{SUBJ} {VERB.PRES} {OBJ}` with 2 distinct example sentences. Never
  loaded at runtime.

Kept in the bundle (real, low risk, may feed future pipeline work):
`Vocabulary/word_frequency_top6000.csv`, `sentences_sqi_50k.csv`,
`morph_rules.json`, `exercise_types.json`.
