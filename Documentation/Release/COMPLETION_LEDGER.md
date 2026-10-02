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
| Spaced repetition scheduler | new (retention pillar) | Documented SM-2 derived model; pure and deterministic with injected clock; deterministic tests for progression, due selection, lapse, day/timezone boundaries | impl |
| Review persistence | new | Per word review state survives relaunch; safe decode of legacy/empty state | impl |
| Review session in daily flow | new | Due reviews reachable from Home; reuse the real exercise UI; per word grade recorded; counts toward streak; does not corrupt lesson completion or unlock state | impl |
| Honest mastery accounting | Phase 0 honesty rule | Profile distinguishes exposure (words seen), practice (words reviewed at least once), and mastery (words at an interval past a documented threshold) | impl |
| Grammar coaching | Phase 3 | FoundationModels gated with deterministic offline fallback; English only; grounded; injection safe; separate from grading | done (verified in tests + build) |
| Audio playback path | Phase 1/2 | Infrastructure, manifest, gating, player all present; 0 reviewed assets ship | blocked-external (needs Azure authorization or native recordings, then native review) |
| Dialect and cultural content | Phase 3 | Gheg sample pack and hospitality unit modeled and gated `pendingNativeReview` | blocked-external (needs native linguistic review) |
| Speaking experiment | Phase 4 | Disabled by default; ASR confidence never shown as pronunciation score; Apple ASR for Albanian confirmed unsupported | done (verified) + superseded for on-device Apple path (see report) |

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
