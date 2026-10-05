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
| Dialect and cultural content | Phase 3 | Gheg sample pack and hospitality unit modeled and gated `pendingNativeReview` | partially superseded by the third pass: content modeling is done and the gate holds. See the third-pass row "Cultural and dialect learner flows" for the learner-facing wiring; the sample content itself is still blocked-external on native linguistic review. |
| Speaking experiment | Phase 4 | Disabled by default; ASR confidence never shown as pronunciation score; Apple ASR for Albanian confirmed unsupported | done (verified) + superseded for on-device Apple path (see report) |
| Experience and quality | step 4 of brief | Cohesive navigation, dark mode, Dynamic Type, keyboard behavior, accessibility metadata across iPhone screens | done (runtime verified: dark mode all screens, Dynamic Type incl. Profile stat cards, keyboard above field; VoiceOver metadata present, spoken pass pending) |
| iPad tailored layout | step 4 of brief | iPad specific layout tuned for the larger canvas | polish (renders correctly today as a scaled iPhone layout; tailoring is a noted non-blocking item) |

## Follow up items completed in the second pass

| Item | Source | Acceptance criteria | Status |
|---|---|---|---|
| Adaptive iPad layout | step 4 of brief | Content constrained to a readable centered column on wide screens; full bleed backgrounds kept; no op on iPhone | done (impl; runtime verified on iPad) |
| Accessibility text truncation | step 4 of brief | Home info pills stack vertically at accessibility sizes instead of truncating; lesson node captions wrap | done (impl; runtime verified) |
| Local daily reminders | step 4 of brief | Opt in, off by default; permission requested on enable; denial explained; daily local time trigger; time picker; off cancels | done (impl + 3 unit tests; runtime verified) |
| Interruption handling | step 3/4 of brief | Quitting a course lesson in progress confirms before discarding; reviews save per answer so they do not confirm | done (impl; runtime verified) |
| Local data control | step 4 of brief | "Reset learning data" clears progress and schedule on device behind a confirmation; goal kept; UI reflects it live | done (impl + 2 unit tests; two runtime bugs found and fixed: a durability flush and a Home tab that did not live refresh after reset; verified on a pristine device) |
| Upgrade behavior | step 4 of brief | Upgrading from pre retention data reads old progress, starts retention empty, does not crash | done (defensive decode unit tested; runtime confirmed no crash with old data and new keys absent). Historical caveat: at the second pass the empty retention state could not be staged on the sim due to cfprefsd caching. This is now closed: the third pass staged it on an erased device with the daemon dropped and observed the empty state directly. See the third-pass "Upgrade behavior re-verification" row. |
| Native review package | step 3 of brief | Concrete list of dialect pairs, cultural unit, and audio set for a native reviewer | done (`REVIEW_PACKAGE.md`) |
| Research corrections | step 2 of brief | Fix the Kim and Webb citation and over claimed figures; confirm Azure sq-AL GA | done (`RESEARCH.md`) |

## Third pass (2026-10-05): resume, culture wiring, upgrade proof, FSRS correction

Build and 66 unit tests pass in 7 suites on iOS Simulator (iPhone 15). Statuses here
are backed by the runtime evidence in `VERIFICATION.md` ("Third pass"), kept distinct
from the unit test coverage.

| Item | Source | Acceptance criteria | Status |
|---|---|---|---|
| Durable course-lesson resume | brief step 1 | Exercise sequence, position, hearts, XP, and combo survive termination and relaunch; no duplicate XP, review scheduling, or completion rewards; saved session cleared on completion, confirmed discard, and learning-data reset; reviews never snapshotted | done (8 unit tests + runtime verified: killed mid lesson, relaunched straight back into the same word order question at 29% with 2 combo and 3 hearts; confirmed discard then relaunch returns to Home) |
| Cultural and dialect learner flows | brief step 2 | Navigation, content presentation, exercises, and progress wired; verified with isolated fixtures; unreviewed production content stays gated; no native approval claimed | done (5 unit tests + runtime verified with the DEBUG `-GjuhaCultureFixtures` arg: hub, unit detail with resolved vocabulary and gated listening, practice through the review engine, dialect contrasts). Production catalog still exposes nothing; the sample content stays `pendingNativeReview` (blocked-external on native review). |
| Upgrade behavior re-verification | brief step 3 | Isolated install with controlled legacy data; preserved progress and correct initial review/reminder state; observed, not hand-waved | done (runtime verified on an ERASED device with legacy keys staged and cfprefsd dropped: XP 92 and streak 3 preserved, Lessons Done 2, In review 0, Mastered 0, no Daily Review card, reminder OFF, no crash). Supersedes the second-pass note that could not stage the empty retention state on the sim. |
| FSRS claim correction | brief step 4 | Separate the DSR scheduling model from parameter optimization; correct "not deterministic"; retain SM-2 if justified by simplicity; no forced migration | done (`RESEARCH.md` rewritten from primary docs: scheduling deterministic given fixed parameters and target retention, FSRS-6 = 21 parameters, default parameters ship so it runs with zero history, the optimizer is the data-dependent step; SM-2 retained for launch simplicity behind the protocol boundary) |

## Deliberate scope boundaries (decided this session, not silently deferred)

- FSRS scheduling: not adopted. SM-2 was chosen for implementation simplicity (no
  optimizer, no parameter file, no personal review history) and full determinism at
  launch; the scheduler sits behind a value type so FSRS can replace it later without
  touching the feature layer. The earlier "FSRS is not deterministic / needs a large
  history to run" framing was corrected: FSRS scheduling is deterministic for a given
  parameter set and target retention, ships with default parameters, and only its
  per-learner parameter optimization is data dependent. See `RESEARCH.md`.
- SwiftData migration of progress: progress stays in the existing UserDefaults store
  (`ProgressStore`, `ReviewStore`). It is small, offline, and relaunch safe, and the
  review and reminder stores decode defensively (verified by the upgrade check).
  Moving to SwiftData is not required for this release and would add migration risk
  for no user visible gain.
- VoiceOver spoken output: labels, values, hints, and traits are set and seen in the
  accessibility hierarchy, but the spoken experience was not driven end to end in
  this environment. This is the one accessibility check that remains, and it needs a
  device with VoiceOver, so it is kept as an explicit external dependency.

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
