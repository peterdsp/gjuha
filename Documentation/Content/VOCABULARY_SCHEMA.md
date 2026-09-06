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
| `gender` | Enum | `m` (masculine), `f` (feminine), `n` (neuter) — nouns only |
| `verbClass` | Enum | `firstConjugation`, `secondConjugation`, `thirdConjugation`, `irregular` — verbs only |
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

## Current Dataset Status (Phase 0)

The bundled dataset the app actually loads is `Data/Seed/Vocabulary/a1_vocabulary.json`
(350 entries, mostly A1 with a few A2). It currently populates the required fields
plus `exampleSentence` / `exampleTranslation`, but does **not** yet populate the
optional `gender` or `verbClass` fields.

Because of this, exercise generation and distractor selection rely on the fields
that are reliably present: `partOfSpeech`, `cefrLevel` and `frequency`. Gender and
verb class are treated as optional and used only when present, so the schema above
describes the target shape while the engine degrades gracefully when they are
absent. Populate `gender` for nouns and `verbClass` for verbs before building
features that depend on them (declension, conjugation drills).

## Albanian-Specific Notes

### Verb entries
- Record the 1st person singular present (citation form in Albanian): `punoj`, `flas`, `kam`
- Include the `verbClass` to support conjugation engine

### Noun entries
- Record the indefinite singular form: `libër`, `vajzë`, `shtëpi`
- Include `gender` — required for article and case generation
- Definite forms are derived automatically by the morphology engine

### Frequency ranking
- 1–500: Core A1 vocabulary (greetings, pronouns, basic verbs, numbers)
- 501–1500: A2 vocabulary (daily life, family, time, weather)
- 1501–3000: B1 vocabulary (work, opinions, abstract concepts)
- 3001–6000: B2+ vocabulary (nuanced, idiomatic, formal)
