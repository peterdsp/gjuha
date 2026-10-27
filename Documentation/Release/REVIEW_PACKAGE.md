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

New in the 1.0 release pass. Gjuha's interface is now driven by String Catalogs
with English as the source language and Albanian (`sq`) as a locale: 158 strings
in the app catalog (`Gjuha/Resources/Localizable.xcstrings`) and 17 in the widget
catalog (`GjuhaWidgets/Localizable.xcstrings`), 170 distinct strings in total.

How the gate works here: every Albanian entry is written with
`"state": "needs_review"`, which is the String Catalog's own flag for "translated
but not checked". Xcode's catalog editor shows these with a review marker, and
filtering to "Needs Review" lists exactly the set below. Marking an entry
`translated` is the sign-off action.

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

Reviewer actions:

1. Open `Gjuha/Resources/Localizable.xcstrings` in Xcode, select Albanian, and
   filter to "Needs Review".
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
5. Plural categories: Albanian uses `one` and `other`. Several entries currently
   carry identical `one` and `other` forms because the noun is invariant
   (`fjalë`, `ditë`). Confirm that is right for each.

Until this review is done, the honest statement is that Gjuha ships an Albanian
interface that has not been checked by a native speaker. That is a lower risk
than unreviewed teaching content, because none of it teaches anything, but it is
not zero and it should be said plainly rather than implied to be complete.
