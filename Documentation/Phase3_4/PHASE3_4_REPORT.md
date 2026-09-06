# Phase 3 & 4 — Distinctive Albanian learning and controlled experiments

This document records what was delivered, the evidence behind it, the linguistic
review status, device limitations, and the release criteria. Nothing here has
been committed, pushed, published, or purchased. All new capabilities sit behind
availability or content gates and are additive.

## 1. Verification before extending

Checked the existing product before building on it:

- Lessons: functioning. The engine generates multiple choice, typed translation,
  and fill in the blank exercises from `a1_vocabulary.json`.
- Persistence: functioning via UserDefaults (`ProgressStore`): completed lessons,
  best XP, streak, and the daily goal. SwiftData holds only `Word` and `Lesson`;
  progress is not stored in SwiftData.
- Audio: at the start of this work it was not a functioning system (data fields
  only, no playback). Recorded audio playback was being added in parallel by a
  separate effort. Apple ships no Albanian text to speech voice, so there is no
  synthetic audio fallback.
- Review scheduling: not a functioning system. `Word.lastReviewedAt` and
  `isLearned` exist but are unused; a "review" lesson is only one whose title
  contains "review". There is no spaced repetition engine. This work did not
  fabricate one; cultural units carry an explicit review step (word ids) ready
  for a future scheduler.

## 2. Research (primary sources, verified against Apple documentation)

### Apple Foundation Models framework
- On device, approximately 3 billion parameter model. Available on iOS, iPadOS,
  macOS, and visionOS 26.0 and later. Requires an Apple Intelligence eligible
  device, Apple Intelligence turned on, and a supported region.
- API used: `SystemLanguageModel.default.availability` (`.available` or
  `.unavailable(reason)`), `supportsLocale(_:)`, and generation through
  `LanguageModelSession(instructions:).respond(to:)`.
- Supported languages are the Apple Intelligence set: English, French, German,
  Italian, Portuguese (Brazil), Spanish, Chinese (Simplified), Japanese, Korean
  ("designed to support 15"). Albanian is not supported.
- Apple documents that input and output safety guardrails apply only to supported
  languages, and that short unsupported text mixed into supported text can bypass
  those checks. This is why the coach never generates free Albanian and never
  presents model generated Albanian as authoritative.

Sources:
- https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models
- https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
- https://machinelearning.apple.com/research/apple-foundation-models-2025-updates

### Apple Speech framework
- `SFSpeechRecognizer.supportedLocales()` mirrors the keyboard dictation locales.
  Some locales require a network connection; `isAvailable` reflects readiness.
- Albanian (sq) is not a dictation locale, so Apple speech recognition of Albanian
  is effectively unavailable. Transcription accuracy is not pronunciation
  assessment.
- Confirmed at runtime: the test `appleSpeechProbeConfirmsAlbanianUnsupported`
  queries the real framework and finds no Albanian locale.

Sources:
- https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportedlocales()
- https://developer.apple.com/documentation/speech/sfspeechrecognizer

## 3. Phase 3 delivered (behind gates)

### 3.1 Grounded grammar coaching
File: `Gjuha/Core/Coaching/GrammarCoach.swift`

- `GrammarCoaching` protocol with `aiAvailability()` and `explain(_:) async`
  (never throws). `@Dependency(\.grammarCoach)`.
- `LiveGrammarCoach` uses Foundation Models only when the model is available and
  English is supported, and always writes in English. On any failure, unsupported
  device, or unsupported language it degrades to a deterministic fallback.
- Grounding (`CoachGrounding`) is built from reviewed grammar data (topic
  explanation, examples, conjugation table). The model instructions forbid
  inventing Albanian: it may quote only Albanian that appears in the reviewed
  notes.
- Untrusted input: the optional learner question is sanitized
  (`CoachInputSanitizer`: strip control characters, cap at 500 characters) and
  isolated inside a delimited data block; the instructions state the learner
  message is data and must not be followed (prompt injection resistance).
- Separation from grading: the coach never grades. Grading stays in
  `ExerciseEngine`. Every result carries a disclaimer that it does not grade
  answers.
- Output guardrail (`TutorGuardrails`): non empty and length bounded; anything
  else falls back.
- Deterministic fallback (`DeterministicGrammarCoach`): pure, offline, always
  available; builds an English explanation from the grounding only.
- UI: `Grammar` topic detail now has an "Explain simply (beta)" panel (Dynamic
  Type, VoiceOver labels) that shows whether the source was AI or the reviewed
  lessons, plus the disclaimer.

### 3.2 Diaspora and Gheg learning
Files: `Gjuha/Core/Content/DialectContentPack.swift`, `ContentCatalog.swift`

- Intended learner defined: heritage and diaspora learners who hear Gheg at home
  while studying Standard Albanian in the app.
- Every entry labels the Standard form and the dialect form explicitly, with
  variety, register, a usage note, and region. No form is marked wrong; the usage
  notes state Gheg is not uniform and varies by region and family.
- Stable identifiers (for example `gheg.family.mother`). `audioAssetId` is nil
  until reviewed native audio exists.
- Review gate: the sample pack is `pendingNativeReview`, so
  `ContentCatalog.productionDialectPacks()` excludes it. Infrastructure is
  complete; the content is held out of production until native review.

### 3.3 Cultural units
File: `Gjuha/Core/Content/CulturalUnit.swift`

- One sample unit, Mikpritja (hospitality), wires vocabulary ids, grammar seed
  ids, listening items, and review word ids (`isFullyWired == true`).
- `hasPlayableAudio == false` (no recorded audio yet, and no synthetic Albanian).
  Held `pendingNativeReview`. The intro sticks to concrete conventions and avoids
  sweeping generalizations.

## 4. Phase 4 delivered (disabled by default, mocks and fixtures)

Selected experiment: speaking and pronunciation feasibility.
File: `Gjuha/Core/Speech/SpeakingExperiment.swift`

Why this one, across the candidate experiments:
- Speaking or pronunciation, best evidence per cost right now: Albanian speech
  support can be established immediately at zero cost and zero privacy risk with a
  read only locale probe, which is exactly what the phase asks to verify first.
- Cloud speaking support: high value but needs cloud processing (not authorized),
  cost, and voice upload privacy handling.
- Albanian conversation practice or tutor handoff: relies on a model that does not
  support Albanian, so it cannot yet produce reliable Albanian. The phase warns
  against promising this until results support it.
- Community audio: valuable but depends on recruiting contributors (not
  authorized) and is mostly a consent, rights, and moderation process.

What is implemented:
- `ExperimentFlags.speakingEvaluationEnabled` is false by default.
- `ExperimentBudget.noSpendWithoutAuthorization`: monthly limit 0, explicit
  authorization required before any charge.
- `SpeechConsent.privacyPreservingDefault`: microphone use explained, no uploads,
  no retention.
- Invariant: transcription is separated from pronunciation. `PronunciationAssessment`
  stays `.unavailable` unless a real assessor scores it; recognition confidence is
  never converted into a pronunciation score. `MockSpeakingEvaluator` is the
  default; `AppleSpeechProbe` is a read only capability probe.

Recommendation: revise or stop the on device Apple path for Albanian speech,
because Apple has no Albanian speech locale. A constrained cloud pilot would
require explicit spending authorization, consented test speakers across accents
and dialects, native reviewed evaluation material, and clear microphone, upload,
and retention disclosures before any go decision. Completed: the feasibility
verification and the disabled prototype. Still required: the cloud pilot decision
and its evaluation.

## 5. Linguistic review status

All new distinctive content (the Gheg pack and the cultural unit) is
`pendingNativeReview` and is excluded from the production catalog by
`ContentCatalog`. No unreviewed content reaches learners. The sample entries are a
starting point for a native reviewer, not an authoritative reference.

## 6. Device limitations

- AI grammar coaching runs only on iOS 26 Apple Intelligence eligible devices with
  Apple Intelligence enabled and English supported. Every other device gets the
  deterministic offline fallback, which is fully functional without AI text.
- No Albanian speech recognition and no Albanian text to speech voice on Apple
  platforms. There is no synthetic listening audio, and the speaking experiment
  cannot use Apple on device recognition for Albanian.

## 7. Evaluation

- Coaching evaluated against a curated set of correct, incorrect, ambiguous, and
  adversarial (prompt injection) questions on the deterministic path (the
  guaranteed offline experience). Assertions: stays grounded, English, does not
  fabricate, carries the does not grade disclaimer, and treats learner input as
  data. The AI path prompt construction, which is the actual safeguard, is
  asserted directly.
- Speech: the real `AppleSpeechProbe` runs in tests and confirms Albanian is not a
  supported locale.
- Result: `xcodebuild test -only-testing:GjuhaTests` passes, 37 tests across 2
  suites (11 new Phase 3 and 4 tests), on iPhone 17 (iOS 26) simulator.

## 8. Release criteria (all must hold before any of this ships to learners)

1. A native reviewer sets `reviewStatus = nativeReviewed` per pack and unit; only
   then does the catalog expose them.
2. Reviewed native audio assets are attached (`audioAssetId` set) before any
   listening or audio dependent content ships. No synthetic Albanian.
3. Grammar coaching: AI path gated on availability and English support;
   deterministic fallback verified on unsupported devices; disclaimers present;
   grading separation preserved; the adversarial suite green.
4. The speaking experiment stays disabled by default. Any cloud path requires
   explicit spending authorization, consent with retention and deletion controls,
   and multi accent native reviewed evaluation before enablement.
5. Accessibility: Dynamic Type and VoiceOver on any new UI, matching the Phase 0
   bar.
6. The full offline course works with every experiment disabled.

## 9. Concurrency note

This work was done while a separate effort added recorded audio and quarantined
old seed artifacts in the same working tree. To avoid clobbering that work, this
session paused until the other effort settled, then verified the merged tree. All
Phase 3 and 4 code is additive and isolated in new files under
`Gjuha/Core/{Coaching,Content,Speech}` plus a thin, contained Grammar UI change.
