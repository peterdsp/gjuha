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

## Fourth pass (2026-10-26): release engineering, localization, platform surfaces

Goal of this pass: make 1.0.0 actually submittable, make the interface
translatable, and add the platform integration a native iOS app is expected to
have. Build and 87 unit tests pass in 10 suites on iOS Simulator (iPhone, iOS
27.1), with zero compiler warnings.

Headline numbers: 66 tests to 87; 0 localizable interface strings to 170 across
two String Catalogs; app bundle assets 8.3 MB to 4.7 MB; bundled seed content
340 KB to 152 KB.

### Release blockers closed

| Item | Acceptance criteria | Status |
|---|---|---|
| Privacy manifest | `PrivacyInfo.xcprivacy` present in the app bundle, declaring no tracking, no collected data, and the one required-reason API actually used | done (`NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1`; verified present in the built bundle) |
| Release version metadata | Marketing version 1.0.0 and build 1 on the app *and* the widget, since App Review rejects a mismatched extension | done (both generated from `project.yml`, so they cannot drift independently) |
| Signing team | Every target signs with one team, so the widget extension cannot end up on a different team than its host app | done (`DEVELOPMENT_TEAM: YTS4KJBX3P` declared once at project level, not per target; all four targets confirmed with `xcodebuild -showBuildSettings`. Value cross-checked against the local provisioning profiles' `TeamIdentifier`, the signing certificate's `OU`, and 12 other local projects). |
| App Group registration | `group.com.gjuha.app` registered against the team and present in the profiles for both bundle ids | done (registered via `xcodebuild -allowProvisioningUpdates -skipMacroValidation` against a device destination; both generated profiles decoded with `security cms -D` and each contains `com.apple.security.application-groups => [group.com.gjuha.app]`) |
| Export compliance | `ITSAppUsesNonExemptEncryption` declared so uploads are not held each time | done (`false`, accurate: no cryptography, no network) |
| Launch screen | Launch background is a real appearance-aware colour instead of an empty `UIColorName` | done (points at the existing `Accent` colour set, which is the first stop of the splash gradient, so the handover has no colour jump) |
| Continuous integration | Build, unit tests, and UI tests on every push and PR, plus a guard that the committed `project.pbxproj` matches `project.yml` | done (`.github/workflows/ci.yml`); **not yet observed green on a hosted runner**, see "External dependencies" below |
| Seed content validation | A failing build when any bundled seed file stops decoding or its references stop resolving | done (`Scripts/validate_seed.py`, wired into CI; passes on 12 units, 120 lessons, 354 vocabulary entries, 3 grammar topics) |

### Localization

| Item | Acceptance criteria | Status |
|---|---|---|
| String Catalogs | Interface strings extracted by the compiler, not by hand, with English source and Albanian (`sq`) as a locale, shipping in both bundles | done (158 app + 17 widget = 170 distinct keys; `sq.lproj` verified present in both the app and the appex; driven by `SWIFT_EMIT_LOC_STRINGS`, so a new string cannot be missed) |
| Untranslatable chrome fixed | No user-facing interface string passed as a plain `String`, which renders verbatim and is never extracted | done (26 strings were previously impossible to translate: the four tab titles, the Profile stat labels, the daily goal and learning reason names, the CEFR filter chips, the culture section headers, the Home metric chips, the grammar coach availability and source labels, and the whole answer-feedback banner) |
| Correct pluralisation | No "1 words" in either language | done (three manual `count == 1 ? "word" : "words"` sites replaced with catalog plural variations; the two Siri strings carrying two counts use `substitutions`, verified in the compiled `stringsdict` with positional arguments) |
| Locale-correct numbers | Bare counts formatted for the locale rather than interpolated into a string | done (three `Text("\(n)")` sites now `Text(n, format: .number)`, which also removes a junk `%lld` catalog key) |
| Albanian translations | Every extracted key has an Albanian entry | impl, **gated** (all 170 translated and marked `needs_review` in the catalogs; no native-speaker pass yet, see `REVIEW_PACKAGE.md` section 4) |

### Platform surfaces

| Item | Acceptance criteria | Status |
|---|---|---|
| WidgetKit extension | Streak, words due, mastered count, and next lesson, in five families, tapping through to the right screen | impl (`GjuhaWidgets`, 632 KB: systemSmall, systemMedium, accessoryCircular, accessoryRectangular, accessoryInline). Builds, embeds, and installs; the rendered widget and its tap targets are **not yet runtime verified**, because that needs placing it on a real Home Screen. See "External dependencies". |
| Widget data sharing without risking learner data | The widget reads shared state, and a misprovisioned App Group cannot lose progress | done (the canonical stores stay in `UserDefaults.standard`; the App Group carries only a derived `GjuhaWidgetSnapshot` projection, rebuilt from the canonical stores on every refresh, so losing it loses nothing). **Runtime verified**: after completing onboarding on the simulator, the shared container for `group.com.gjuha.app` exists and holds a snapshot whose `nextLessonTitle` is `Greetings & introducing yourself`, which is L001 in `lessons.json`, so the projection is reading the real curriculum and not a default. |
| Honest widget under staleness | The widget never quotes a count it cannot stand behind | done (the counts are day-relative and the widget cannot recompute them, so once the calendar day turns it hides them and asks the learner to open the app; 5 unit tests including a 20-minute-across-midnight case) |
| App Intents | Siri, Shortcuts, and Spotlight entry points for review, continue, and progress | impl (4 intents, 8 phrases; `supportedModes` rather than the deprecated `openAppWhenRun`; `StartReviewIntent` runs in the background to answer "nothing is due" without opening the app and escalates with `continueInForeground` only when there is a session to run). `Metadata.appintents` is generated in the built app and the build reports no dropped phrases, which is the evidence that extraction worked; **actually speaking to Siri is not verified** and needs a device. |
| One path in from outside | Siri, Shortcuts, and a widget tap take identical code paths into app state | done (everything funnels through `GjuhaDeepLink` and `GjuhaIntentRouter`; a cold launch holds the link until the curriculum loads, then resolves it) |
| Deep links cannot destroy work | An external trigger never discards a lesson in progress | done (`resolve` bails out whenever anything is on the navigation path, so the existing explicit discard confirmation stays the only way to lose answers) |
| No fabricated progress | Nothing reachable from outside the app can bank XP or complete a lesson | done (by construction: the intents only navigate or report) |

### Test coverage and quality

| Item | Acceptance criteria | Status |
|---|---|---|
| Critical-flow UI tests | The paths no unit test can reach are covered | done (`GjuhaUITests` went from an 11-line empty shell to 6 tests: onboarding to lesson map, onboarding not repeating, every root tab, Profile separating exposure from mastery, opening a lesson and the quit confirmation, and the reset confirmation) |
| Deterministic UI test state | No test depends on run order or leftover state | done (DEBUG-only `-GjuhaResetStateForUITests` launch hook, named keys rather than a wildcard wipe, compiled out of release builds entirely) |
| Unit tests for the new surfaces | Deep links, the widget projection, and the next-lesson rule are tested as pure functions | done (21 new tests in 3 suites: 66 to 87) |
| Zero compiler warnings | A clean build with no deprecations | done (migrated `NavigationStackStore` to `NavigationStack(path:)` per TCA 1.7's migration note, on TCA 1.26.2; removed an unreferenced app icon asset) |

### Bundle hygiene

| Item | Acceptance criteria | Status |
|---|---|---|
| Nothing ships without a reader | Every file in the app bundle is read by something | done (5 seed files totalling ~185 KB were in the app target but read by no Swift code and by no pipeline script; moved to `Content/archive/` with provenance. `a1_lessons.json` was the actively misleading one: it looks like the curriculum, while the real curriculum is `units.json` plus `lessons.json`) |
| Dead assets removed | No asset groups for targets this app does not have | done (35 icon-generator leftovers removed: Apple Watch, Messages, App Store, and legacy iOS 5 to 12 icon sets, none referenced in code; assets 8.3 MB to 4.7 MB) |
| Colours defined once | The widget and the app cannot drift to different brand colours | done (14 colour sets moved to a shared `Palette.xcassets` included by both targets, so the widget carries 60 KB rather than the 8 MB catalog, and the values exist in exactly one place) |

### Bugs found and fixed during this pass

1. **The widget extension could not install at all.** xcodegen *generates* the
   file at `info.path` from `info.properties`, so a hand-written
   `GjuhaWidgets/Info.plist` was silently overwritten on the next
   `xcodegen generate`, dropping the `NSExtension` dictionary. The app then failed
   to install on the simulator with "extensionDictionary must be set in
   placeholder attributes for an app extension placeholder", which reads as a
   signing or simulator problem rather than a config one. Fixed by declaring the
   extension point in `project.yml`. Note this broke installing the *whole app*,
   not just the widget.
2. **The App Group entitlement was silently dropped.** The same xcodegen
   behaviour as bug 1, in a second place: `entitlements.path` is also a
   *generated* file, so both hand-written `.entitlements` files were overwritten
   with an empty `<dict/>`, confirmed by reading the files back off disk. The
   consequence is worse than it looks and completely silent: with no App Group,
   `UserDefaults(suiteName:)` still returns a usable object and still persists,
   but into the app's own container, so the app would have written widget
   snapshots that the widget could never read, forever, with no error anywhere.
   The symptom that exposed it was that the simulator had no shared container for
   `group.com.gjuha.app`, and `group.com.gjuha.app.plist` was sitting inside the
   app's own `Library/Preferences` instead. Fixed by declaring the group in
   `project.yml`.

   A note on evidence, because one check here is a trap: `codesign -d
   --entitlements` reports nothing for a *simulator* build even when entitlements
   are correct, because simulator builds embed them in a `__TEXT,__entitlements`
   Mach-O section rather than in the code signature. It was used during diagnosis
   and its empty output was not, on its own, proof of anything. The claims above
   rest on the file contents and the container layout; the fix was confirmed by
   finding the entitlement string in both binaries and by the shared container
   appearing.

   This is also the case the projection design was built for: because only a
   derived projection lives in the App Group, this bug cost the widget its data
   and cost the learner nothing.
3. **26 interface strings could never be translated**, because `Text(someString)`
   renders verbatim and is never extracted. Listed above. This was invisible
   before the catalog existed, since there was nothing for them to be missing
   from.
4. **Three manual pluralisation sites** would have produced "1 words ready to
   strengthen" in English and would not have inflected at all in Albanian.
5. **An empty accessibility value.** A matching exercise announced `""` for an
   unmatched pair, which VoiceOver reads as silence; it now says "not matched".
6. **An unreferenced 1024px app icon** in the icon set produced a build warning
   ("unassigned child") and was byte-identical to the marketing icon already
   wired up.
7. **Perpetual decorative animations ignored Reduce Motion.** The onboarding
   backdrop's drifting circles, the floating Albanian phrase chips, the Home
   streak and XP pulses, the next-lesson breathing ring, and the looping GIF
   mascot all animated forever regardless of the setting. Only the mascot's
   *still-image fallback* was gated, which meant the looping animation kept
   playing for exactly the people who had asked for less motion. Found because
   it also broke the UI tests: a view that never stops animating never reaches
   quiescence, so XCUITest's synthesised taps were being swallowed and the
   onboarding flow looked like it was ignoring button presses.

## Deliberate scope boundaries (decided this session, not silently deferred)

- Minimum iOS raised from 17 to **27** at the user's explicit direction. This is
  recorded as a tradeoff, not a neutral upgrade: it limits installs to devices on
  the newest major iOS, which cuts against the diaspora audience in `RESEARCH.md`
  who are likeliest to be on older hardware. Nothing in the code requires it. The
  widget and App Intents work on iOS 17, and the two iOS 26+ App Intents
  properties in use (`supportedModes`, `allowedExecutionTargets`) can be
  availability gated. Lowering the floor later is a `project.yml` change plus
  availability annotations and does not touch feature code.
- Albanian interface strings ship as `needs_review` rather than being held back.
  Reasoning: the catalogs contain interface chrome only, never teaching content,
  so an imperfect label is a cosmetic problem rather than teaching someone wrong
  Albanian. Holding the locale back entirely would have meant shipping an
  Albanian-language app with an English-only interface. The gate is recorded in
  `REVIEW_PACKAGE.md` section 4 and is visible in Xcode's catalog editor.
- Progress stays in UserDefaults, and the App Group holds only a derived
  projection. Moving the canonical stores into the shared suite would have been
  the obvious way to feed the widget, and was rejected: an App Group that is not
  enabled on the signing profile fails *silently*, which would turn a signing
  mistake into a learner losing their progress. A stale widget is a far cheaper
  failure.
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
4. **Hosted CI cannot compile the app, confirmed on a real run.** This is no
   longer a prediction. On run 40578928874 the newest GitHub-hosted macOS image
   gave Xcode 26.6 with only the iOS 26.5 SDK, so there is no iOS 27 SDK on any
   hosted runner. With a 27.0 deployment target the app cannot be built in hosted
   CI at all. The workflow now treats this as the environment limitation it is:
   it emits a visible warning and skips the compile, test, and localization-guard
   steps, while project generation, the committed-pbxproj drift check, the
   em-dash house rule, and seed validation still run on every push. The
   consequence is real: **until a runner image ships the iOS 27 SDK, no automated
   build or test protects this repository.** Lowering the floor to iOS 26 would
   make the job build and test for real, and is a one line change in
   `project.yml` plus availability annotations on two App Intents properties.
5. Native-speaker review of the 170 Albanian interface strings (`REVIEW_PACKAGE.md`
   section 4).
6. The widget's *rendering* and the App Intents' *invocation* are not runtime
   verified. The data path underneath both is: the shared container is created,
   the app writes a correct projection into it, and the deep link and next-lesson
   rules are unit tested. What remains needs real hardware and a signing team:
   placing the widget on a Home Screen and a Lock Screen and seeing the five
   families draw, tapping each one through to the right screen, and speaking the
   four App Shortcut phrases to Siri. `Metadata.appintents` is generated in the
   built app with no dropped phrases, which is evidence that extraction worked,
   not that Siri answers. The device checklist is in `APP_STORE_SUBMISSION.md`
   section 8.

## Verification log

See `VERIFICATION.md` for build, test, and simulator runtime evidence.
