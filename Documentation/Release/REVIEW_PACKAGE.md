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
