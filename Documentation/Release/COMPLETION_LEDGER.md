# Gjuha Completion Ledger

Living record of unfinished work, acceptance criteria, status, and verification.
Derived from code and behavior, not README checkboxes. Updated as work lands.

Date opened: 2026-10-03. Baseline integrated commit: `44a3a88` (Phase 0 + Phase 1 +
Phase 3/4 merged). Build and 37 unit tests pass on iOS Simulator (iPhone 15).

## Legend

Status: `done` (implemented and runtime verified), `impl` (implemented, tests pass,
not yet runtime verified), `blocked-external` (needs account access or human review),
`superseded` (intentionally dropped, with reason).

## Recovery and reconciliation

| Item | Status | Notes |
|---|---|---|
| Uncommitted Phase 3/4 working tree (Coaching, Content, Speech, Grammar) | done | Byte identical to branch `phase3-4-distinctive-learning`. Preserved in stash + bundle, then integrated via merge. |
| Branch `phase3-4-distinctive-learning` (1140fcd, base ed925b7) | done | Merged onto current `main` (2d9c236) in `44a3a88`. Only real conflicts: `project.pbxproj` and `GjuhaTests.swift`, both resolved keeping Phase 1 audio plus Phase 3/4 additions. |
| Stale worktree `/Users/peterdsp/git/gjuha-phase34` | done | Directory already absent; registration pruned after inspection. |
| Snapshot backup | done | `git bundle --all` plus tarball of working tree in session scratchpad before any branch switch. |

## Release scope (this session)

The chosen differentiator is durable retention. The single biggest missing learning
pillar was spaced repetition: nothing in the tree scheduled review of learned words.
It is fully offline, deterministic, and testable, and it is what separates a serious
adult course from the generic template competitors (Ling, uTalk, 50Languages) and
from Duolingo, which has no Albanian course at all.

| Item | Source | Acceptance criteria | Status |
|---|---|---|---|
| Spaced repetition scheduler | new (retention pillar) | Documented SM-2 derived model; pure and deterministic with injected clock; deterministic tests for progression, due selection, lapse, day/timezone boundaries | done (12 unit tests, runtime verified) |
| Review persistence | new | Per word review state survives relaunch; safe decode of legacy/empty state | done (unit test + relaunch verified) |
| Review session in daily flow | new | Due reviews reachable from Home; reuse the real exercise UI; per word grade recorded; counts toward streak and Total XP; does not corrupt lesson completion or unlock state | done (runtime verified; review XP banking bug found and fixed) |
| Honest mastery accounting | Phase 0 honesty rule | Profile distinguishes exposure (words seen), practice (in review), and mastery (words at an interval past a documented threshold) | done (runtime verified: In review and Mastered shown) |
| Grammar coaching | Phase 3 | FoundationModels gated with deterministic offline fallback; English only; grounded; injection safe; separate from grading | done (verified in tests + build) |
| Audio playback path | Phase 1/2 | Infrastructure, manifest, gating, player all present; 0 reviewed assets ship | blocked-external (needs Azure authorization or native recordings, then native review) |
| Dialect and cultural content | Phase 3 | Gheg sample pack and hospitality unit modeled and gated `pendingNativeReview` | blocked-external (needs native linguistic review) |
| Speaking experiment | Phase 4 | Disabled by default; ASR confidence never shown as pronunciation score; Apple ASR for Albanian confirmed unsupported | done (verified) + superseded for on-device Apple path (see report) |
| Experience and quality | step 4 of brief | Cohesive navigation, dark mode, Dynamic Type, keyboard behavior, accessibility metadata across iPhone screens | done (runtime verified: dark mode all screens, Dynamic Type incl. Profile stat cards, keyboard above field; VoiceOver metadata present, spoken pass pending) |
| iPad tailored layout | step 4 of brief | iPad specific layout tuned for the larger canvas | polish (renders correctly today as a scaled iPhone layout; tailoring is a noted non-blocking item) |

## Deliberate scope boundaries (decided this session, not silently deferred)

- Local notification reminders: not implemented. The repository had no notification
  code, so this was never a started commitment. Doing it properly needs a permission
  request, a user facing reminder time and on/off control, scheduling with correct
  timezone handling, and tests; a half wired version would be exactly the disabled
  scaffolding the brief warns against. In app motivation is provided instead by the
  streak and the due review card, which only appears when work is actually due (it
  never nags with an empty queue). Reminders are a clean next increment.
- FSRS scheduling: not adopted. SM-2 was chosen for determinism and zero training
  data at launch; the scheduler sits behind a value type so FSRS can replace it later
  without touching the feature layer. See `RESEARCH.md`.
- SwiftData migration of progress: progress stays in the existing UserDefaults store
  (`ProgressStore`, `ReviewStore`). It is small, offline, and relaunch safe, and the
  review store decodes defensively. Moving to SwiftData is not required for this
  release and would add migration risk for no user visible gain.

## External dependencies (cannot be closed without access or human review)

1. Native-reviewed Albanian audio. Only Azure Neural TTS supports Albanian well
   (`sq-AL-AnilaNeural`, `sq-AL-IlirNeural`). Needs billing authorization, then
   native-speaker review before any manifest entry is marked `reviewed:true`.
2. Native linguistic review of the Gheg dialect pack and the hospitality cultural
   unit before they move from `pendingNativeReview` to production.
3. Apple on-device ASR and TTS do not support Albanian (verified at runtime). No
   synthetic listening audio is generated.

## Verification log

See `VERIFICATION.md` for build, test, and simulator runtime evidence.
