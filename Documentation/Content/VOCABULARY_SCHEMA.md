# Vocabulary Dataset Schema

Every word entry in `Data/Seed/Vocabulary/*.json` must conform to this schema.

---

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Unique identifier (e.g., `"w001"`) |
| `albanian` | String | The Albanian word or phrase |
| `english` | String | English translation |
| `cefrLevel` | Enum | `a1`, `a2`, `b1`, `b2`, `c1`, `c2` |
| `partOfSpeech` | Enum | See below |
| `frequency` | Int | Frequency rank (lower = more common) |

## Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `gender` | Enum | `m` (masculine), `f` (feminine), `n` (neuter) - nouns only |
| `verbClass` | Enum | `firstConjugation`, `secondConjugation`, `thirdConjugation`, `irregular` - verbs only |
| `exampleSentence` | String | Example sentence in Albanian |
| `exampleTranslation` | String | English translation of example |
| `audioFileName` | String | Filename in `Resources/Audio/` (without extension) |

## Part of Speech Values

`noun`, `verb`, `adjective`, `adverb`, `pronoun`, `preposition`, `conjunction`, `interjection`, `numeral`, `particle`

---

## Naming Conventions

- Files named by CEFR level: `a1_vocabulary.json`, `a2_vocabulary.json`, etc.
- IDs use zero-padded numbers: `w001` through `w9999`
- Albanian text must use correct diacritics: ë, ç, sh, zh, xh, gj, nj

---

## Current Dataset Status (Phase 1)

`Data/Seed/Vocabulary/a1_vocabulary.json` is the **single canonical vocabulary
source** (354 entries, mostly A1 with a few A2). Both the exercise engine and the
vocabulary browser load it, so a word has one stable `wNNN` identity everywhere.
The old second source, `vocabulary_seed_600.csv`, was retired in Phase 1: it was
mostly `__TODO_WORD__` placeholders plus duplicates and surfaced fake rows in the
browser. It is quarantined under `Quarantine/`; the four real curated words it
had that the JSON lacked (je, është, përshëndetje, të lutem) were merged in as
w351-w354.

Field coverage today: all entries have the required fields plus `frequency`; 190
have `exampleSentence` / `exampleTranslation`; 155 nouns have `gender`; 73 verbs
have `verbClass`. The engine uses `gender` / `verbClass` when present (for grammar
notes and distractor affinity) and degrades gracefully when absent. Continue
populating `gender` for nouns and `verbClass` for verbs to strengthen declension
and conjugation features.

`audioFileName` is normally left unset in the JSON: pronunciation audio is wired
through `Data/Seed/audio_manifest.json` instead (keyed by `wNNN`), so a word only
carries a clip when one genuinely ships and has passed native-speaker review. See
`Documentation/Content/AUDIO_PIPELINE.md`.

## Albanian-Specific Notes

### Verb entries
- Record the 1st person singular present (citation form in Albanian): `punoj`, `flas`, `kam`
- Include the `verbClass` to support conjugation engine

### Noun entries
- Record the indefinite singular form: `libër`, `vajzë`, `shtëpi`
- Include `gender` - required for article and case generation
- Definite forms are derived automatically by the morphology engine

### Frequency ranking
- 1-500: Core A1 vocabulary (greetings, pronouns, basic verbs, numbers)
- 501-1500: A2 vocabulary (daily life, family, time, weather)
- 1501-3000: B1 vocabulary (work, opinions, abstract concepts)
- 3001-6000: B2+ vocabulary (nuanced, idiomatic, formal)
