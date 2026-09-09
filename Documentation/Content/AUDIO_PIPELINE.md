# Pronunciation Audio: Providers, Pipeline, and Release Dependency

Phase 1 builds the full offline audio *infrastructure* (manifest, player, listening
exercise, vocabulary playback, generation pipeline). It does **not** ship
pronunciation audio, because producing correct, licensable, reviewed Albanian
audio requires either an authorized paid provider or native recordings, plus a
native-speaker review pass. That reviewed audio is the remaining release
dependency. This document records the provider research behind that decision and
how to run the pipeline once audio is authorized.

## Provider research (September 2026)

Albanian (Standard Albanian / Tosk, `sq` / `sqi`) is supported by far fewer
speech providers than most European languages. Findings, most to least useful
for this app:

| Provider | Albanian? | Model / voice | Cost | Bundling generated audio | Notes |
|---|---|---|---|---|---|
| **Microsoft Azure AI Speech** | **Yes** | Neural: `sq-AL-AnilaNeural` (F), `sq-AL-IlirNeural` (M) | Paid; neural free tier ~0.5M chars/month | Allowed under Azure terms (synthesized speech may be used in apps) | Recommended production path. The full A1 set (~350 words, ~6k chars) fits well inside the monthly free tier. Requires an Azure account + key. |
| Apple on-device (`AVSpeechSynthesizer`, macOS `say`) | **No Albanian voice** | n/a | Free, offline | Output usable, but there is no Albanian voice | Verified locally: 184 `say` voices, none Albanian; iOS ships no `sq` voice. Reading Albanian with a non-Albanian voice mispronounces it, so this is **development only** and must never be labeled production. |
| Meta MMS-TTS (`facebook/mms-tts-sqi`) | **Yes** | VITS checkpoint | Free, self-hostable | **Prohibited for commercial use** | License is CC-BY-NC-4.0 (non-commercial). Fine for personal prototyping, **not** for a shipping commercial app. |
| Google Cloud Text-to-Speech | **No** | n/a | n/a | n/a | Albanian is not in the supported language list. |
| ElevenLabs | Not offered | n/a | n/a | n/a | Albanian is not officially listed for any model. |
| Amazon Polly | Not supported (unconfirmed) | n/a | n/a | n/a | Albanian is not in Polly's documented language list; treat as unsupported until confirmed from primary docs. |

Sources: Azure language support and the neural-voice announcement
(learn.microsoft.com / techcommunity.microsoft.com), `facebook/mms-tts-sqi`
model card (huggingface.co, license cc-by-nc-4.0), and local inspection of macOS
`say -v '?'`.

## Decision

- **Production:** Azure Neural TTS `sq-AL-*`, generated at build time, cached and
  bundled, then **reviewed by a native speaker** before any manifest entry is
  marked `reviewed: true`. Native recordings are an equally valid or better
  source and use the same manifest and review gate.
- **Development:** `apple-say` may generate placeholder clips to exercise the
  pipeline, always `reviewed: false` and never wired into graded lessons.
- **Do not** use Meta MMS-TTS in the shipping app (non-commercial license).
- **Do not** incur Azure charges without explicit authorization. Keys live only
  in environment variables, never in the app binary or this repository.

## What ships in Phase 1

- `Gjuha/Data/Seed/audio_manifest.json` - the explicit manifest (currently zero
  assets; the structure and provenance contract are in place).
- `AudioManifest` / `AudioLibrary` - load the manifest and resolve entries to
  files, serving a clip only when it is present and (for lessons) reviewed.
- `AudioPlayerClient` - plays a bundled clip, or falls back to an on-device
  Albanian voice *only if one is installed*, so the app never speaks Albanian
  with a wrong-language voice.
- Listening exercises (`tapWhatYouHear`) are fully implemented but generated only
  when reviewed audio exists, so none are exposed today.
- The vocabulary browser shows a play control only when a word has a reviewed
  clip or the device has an Albanian voice.

## Provenance recorded per asset

`wordId`, `text` (exact spoken Albanian), `file`, `provider`, `voice`,
`license`, `reviewed` (native-speaker approved), `generatedAt`, `checksum`.

## Running the pipeline

```bash
# Development placeholder audio (free, offline, wrong-voice - never production):
python3 Scripts/tools/generate_audio.py --provider apple-say --limit 20

# Production (requires an authorized Azure key; may incur cost beyond free tier):
export AZURE_SPEECH_KEY=...            # never commit
export AZURE_SPEECH_REGION=westeurope
python3 Scripts/tools/generate_audio.py --provider azure --yes-incur-cost

# Validate the manifest against files on disk (missing-asset check):
python3 Scripts/tools/generate_audio.py --validate
```

The generator is reproducible and cached: it hashes `(provider, voice, text)` and
skips clips already produced. It always writes `reviewed: false`; flipping an
entry to `reviewed: true` is a deliberate human step after native-speaker review
(see the ë, ç, gj, xh, stress and dialect checklist in the review notes below).

## Native-speaker review checklist (gate for `reviewed: true`)

- `ë` (schwa) pronounced, not dropped or turned into a full vowel.
- `ç` vs `c`, and the digraphs `gj`, `xh`, `nj`, `sh`, `zh`, `dh`, `th`, `ll`, `rr`.
- Word stress on the correct syllable.
- Standard (Tosk) pronunciation unless a lesson is explicitly dialectal.
- The clip matches the exact `text` in the manifest.
