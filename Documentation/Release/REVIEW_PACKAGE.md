# Native Review Package

Everything a native Albanian reviewer needs to approve before the gated content and
any pronunciation audio can ship. The implementation around each item is complete;
only the human review and the recordings are outside the codebase.

How the gate works: `ReviewStatus` is `pendingNativeReview` on all content below, and
`ContentCatalog.production*` returns only `nativeReviewed` items, so none of this
reaches learners until a reviewer confirms it and the status is changed with the
review recorded. Audio shows only when a manifest entry is both present and
`reviewed: true`.

## 1. Gheg dialect pack (`DialectContentPack.swift`, `samplePack`)

Teaches Standard Albanian (Tosk based literary norm) and labels these Gheg forms as
regional, never as "correct". Reviewer confirms each pair is accurate, the register
is right, and the region note is fair.

| Gloss | Standard (Tosk) | Gheg form | Region note |
|---|---|---|---|
| mother | nënë | nanë | Kosovo and northern Albania (varies locally) |
| how are you? | si je? | qysh je? | Kosovo and northern Albania (varies locally) |
| to work (infinitive) | të punoj | me punue | Northern Albania and Kosovo |
| I will go | do të shkoj | kam me shku | Northern Albania and Kosovo |
| where | ku | kah | Kosovo and northern Albania (varies locally) |

Reviewer actions: confirm or correct each form, the `usageNote`, and `region`; flag
any form that is too local to label broadly. On sign off, set `reviewStatus` to
`nativeReviewed` and record who reviewed it and when.

## 2. Cultural unit "Mikpritja: welcoming a guest" (`CulturalUnit.swift`, `sampleUnit`)

A hospitality unit connecting vocabulary, grammar, dialogue, and a small listening
set (offering, accepting, politely declining coffee and the words around a visit).
Reviewer confirms the phrases are natural and the cultural framing is accurate and
not over generalized across families and regions.

## 3. Pronunciation audio (`audio_manifest.json`, currently 0 assets)

No audio ships yet. The licensing path is Azure Neural TTS Albanian, voices
`sq-AL-AnilaNeural` (female) and `sq-AL-IlirNeural` (male), both General Availability,
or native speaker recordings. Needs billing authorization first (keys in env vars
only, no charges without authorization), then generation via
`Scripts/tools/generate_audio.py`, then native review of every clip before any
manifest entry is marked `reviewed: true`.

Recommended first recording set: the A1 vocabulary that backs the most exercises,
starting with the greetings and core verbs already in `a1_vocabulary.json` (for
example w001 mirëdita, w002 mirëmëngjes, w006 faleminderit, w018 jam, w019 kam).
A clip is accepted only when a native speaker confirms the pronunciation; ASR
confidence is never used as a proxy for pronunciation accuracy.

## What is NOT blocked

All the surrounding implementation (the review gate, the dialect and cultural data
models, the audio manifest, player, and gating, and the exercise wiring) is complete
and covered by unit tests. This package is the human and licensing work that the code
is already built to accept.

## 4. Albanian interface strings (`Localizable.xcstrings`, locale `sq`)

Gjuha's interface is driven by String Catalogs with English as the source
language and Albanian (`sq`) as a locale: 213 strings in the app catalog
(`Gjuha/Resources/Localizable.xcstrings`) and 20 in the widget catalog
(`GjuhaWidgets/Localizable.xcstrings`).

**208 app strings and 19 widget strings await this review.** Run
`python3 Scripts/check_localization.py` for the current count at any time; it
prints the number and never lets it drift.

There are two kinds, and they need different handling in Xcode:

- **`needs_review`**, the majority. A machine-assisted Albanian translation
  exists and nobody has read it. Xcode's catalog editor marks these, and
  filtering to "Needs Review" lists them.
- **`new`, currently 10 strings.** No Albanian exists at all; the app falls back
  to English for these. **Filtering to "Needs Review" does not show them**, so
  they are easy to finish the pass without ever seeing. In Xcode they appear
  with the Albanian cell empty. They are listed by name in step 5 below.

Marking an entry `translated` is the sign-off action for both kinds.

**This review covers Android as well.** The Android resources are generated from
this catalog by `Scripts/sync_android_strings.py`, with the English deliberately
identical so the Albanian transfers verbatim. There is no second set to read,
and CI fails if the two drift apart. A correction made here reaches Android by
re-running that script.

What is and is not in scope:

- **In scope: interface chrome only.** Buttons, tab titles, screen titles,
  settings labels, empty states, accessibility labels and hints, Siri and
  Shortcuts phrasing, and widget captions.
- **Not in scope: teaching content.** Vocabulary, example sentences, grammar
  explanations, conjugation tables, the dialect pack, and the cultural unit all
  come from the seed JSON in `Gjuha/Data/Seed/` and are unaffected by this
  catalog. They keep their own review gates (sections 1 to 3 above).
- **Not in scope: grammar coach output.** `CoachExplanation.text` and its
  disclaimer are generated English prose and are deliberately left in English.
  Translating the disclaimer while the explanation stays English would be worse
  than leaving both.

Reviewer actions. There are two routes, and the second needs no developer
tools:

**Route A, a spreadsheet.** `Documentation/Release/albanian-review.csv` holds
every pending string with its English, its current Albanian draft, and a note
where there is no draft at all. It opens in Numbers, Excel or Google Sheets.
The reviewer edits the `albanian` column and writes `ok` in `approved` for each
line they are happy with, then sends it back. Nothing is marked reviewed
without that word, so a half finished pass cannot look complete, and a line
approved with an empty translation is refused rather than written.

    python3 Scripts/review_strings.py export    # refresh the CSV first
    python3 Scripts/review_strings.py import    # fold the answers back in

The committed CSV is a snapshot. Export again before sending it to anyone, so
it matches the code they will be reviewing. After importing, re-run
`Scripts/sync_android_strings.py` so Android picks up the corrections.

**Route B, Xcode.**

1. Open `Gjuha/Resources/Localizable.xcstrings` in Xcode, select Albanian, and
   filter to "Needs Review". Then clear the filter and look for the entries with
   an empty Albanian cell, which that filter hides. Both sets need doing.
2. For each string, confirm or correct the Albanian, then mark it translated.
   Register matters: the app addresses an adult learner. The existing strings mix
   the second person singular and plural inconsistently in places (for example
   "Mëso shqip" alongside "Pse po mësoni shqip?"), and picking one register
   throughout is a judgement call for a native speaker, not a mechanical fix.
3. Repeat for `GjuhaWidgets/Localizable.xcstrings`.
4. Pay particular attention to these, where a wrong choice is user visible and
   not obvious from the English:
   - `Words seen`, `In review`, `Mastered`. These three are Gjuha's honest
     progress claim and must stay clearly distinct from one another in Albanian.
     "Mastered" must not read as a stronger claim than the scheduler supports.
   - `Day streak` and the `%lld day streak` plural forms.
   - `Casual`, `Regular`, `Serious`, `Intense`. Daily goal levels, currently
     translated as adjectives agreeing with an implied masculine noun.
   - The four App Shortcut phrases. These are spoken to Siri, so they must sound
     like something a person would actually say, and each one must keep the
     `${applicationName}` token or the phrase is dropped by the system index.
   - `Mirë se vini` is intentionally Albanian in the English build and is marked
     "should not translate".
5. The 10 strings with no Albanian at all. These are the exercise prompts and
   their hints, and they matter more than the rest of the chrome: they are the
   questions themselves, so a learner reads them on every exercise. They were
   previously built by string interpolation inside the exercise engine and so
   could not be translated at all; they are catalog keys now.

   | Key | What the learner sees |
   |---|---|
   | `What does '%@' mean?` | `%@` is the Albanian word, never translated |
   | `How do you say '%@' in Albanian?` | `%@` is the English word |
   | `Translate: '%@'` | Used in both directions, so the Albanian must read naturally for either |
   | `Arrange the words to say: "%@"` | `%@` is an English sentence |
   | `%@ (%@)` | A sentence with a gap, then what it means. Keep both parts |
   | `Match each word to its meaning` | Instruction above a matching grid |
   | `Tap what you hear` | Listening exercise, no audio ships yet |
   | `Type in Albanian` | Field hint |
   | `Type in English` | Field hint |
   | `Tap the words in order` | Hint under the word order exercise |

   Register matters most here, because these are read constantly. The imperative
   is natural in Albanian for instructions, but the choice between singular and
   plural address should match whatever is chosen in step 2.

6. Plural categories: Albanian uses `one` and `other`. Several entries currently
   carry identical `one` and `other` forms because the noun is invariant
   (`fjalë`, `ditë`). Confirm that is right for each.

Until this review is done, the honest statement is that Gjuha ships an Albanian
interface that has not been checked by a native speaker. That is a lower risk
than unreviewed teaching content, because none of it teaches anything, but it is
not zero and it should be said plainly rather than implied to be complete.
