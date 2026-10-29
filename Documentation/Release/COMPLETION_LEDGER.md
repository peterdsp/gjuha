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

### Found while lowering the floor

| Item | Acceptance criteria | Status |
|---|---|---|
| SwiftData store location pinned | Adding an App Group must not silently move where SwiftData keeps its store | done. CoreData resolves its default store directory to the **App Group** container when the app is entitled to exactly one group, so adding the group for the widget relocated this store with no code change. Harmless today, because **nothing in the app reads or writes SwiftData at all**: `Word` and `Lesson` are declared `@Model`, but all data comes from the JSON seed through the repositories and everything the learner produces lives in the UserDefaults backed stores. It would have silently relocated real data the moment any was written, so `ModelConfiguration` now takes an explicit URL in the app's own container. Also creates Application Support if missing, which stops a clean launch logging a wall of CoreData stat and sandbox errors. |
| Noted, not fixed: a `fatalError` on an unused container | | `GjuhaSchema.container` calls `fatalError` if creation fails, which can stop the app launching over a store nothing needs. Left alone because making it survivable means deciding what the app does without SwiftData, which is a Phase 2 decision rather than a release fix. Recorded in the source. |

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

- Minimum iOS is **26.0**. It was raised from 17 to 27 during this pass at the
  user's direction, and then lowered to 26 once the cost became measurable rather
  than theoretical: **no GitHub-hosted runner ships an iOS 27 SDK**, so at a 27
  floor the app could not be compiled in CI and the pipeline had to skip its
  build and test steps entirely. Lowering it cost nothing. Exactly one iOS 27
  only API was in use, `allowedExecutionTargets` on the four App Intents, and it
  was redundant: with no App Intents extension the system already runs them in
  the main app process, and Apple's guidance is to prefer the default over
  pinning `.main`. Removing it was a strict improvement. Verified at the floor,
  not just on the newest runtime: 87 tests pass on an iOS 26.5 simulator.
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
4. ~~Hosted CI cannot compile the app.~~ **Resolved.** It was real: on run
   40578928874 the newest hosted image gave Xcode 26.6 with only the iOS 26.5
   SDK, so at the then-current iOS 27 floor nothing could be compiled and the
   build and test steps had to be skipped, leaving the repository with no
   automated protection. Fixed by lowering the floor to iOS 26 and removing the
   one redundant iOS 27 only API. CI now builds, unit tests, and UI tests on every
   push, with no skip conditions.
5. Native-speaker review of the 226 Albanian interface strings (`REVIEW_PACKAGE.md`
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

## Fourth pass: design system and retention loop

Opened 2026-10-29. The brief was to bring the app to release-grade polish. The
work divided cleanly into defects found by measuring, and one loop that was built
but never closed.

### Colour, measured rather than asserted

The palette had light and dark variants and nothing else, and several tokens were
being used in a role they could not carry. Measuring every pair the app actually
renders produced this:

| What | Measured | Effect |
|---|---|---|
| Gold (`XP`) as text on `Surface` | **1.76:1** | The XP number on Home, the Total XP and Mastered stat tiles, and the widget's star were all effectively unreadable in light appearance. |
| White on the amber near-miss banner | **1.76:1** | The line telling a learner what they spelled wrong was the hardest line in the app to read. |
| White on the `Success` banner | **2.70:1** | Below even the 3:1 graphical floor. |
| White on the `Streak` gradient stop | **2.61:1** | Under the bold label of every primary button. |
| `TextTertiary` on `Background` | **2.70:1** light, **2.99:1** dark | Real captions, in both appearances. |
| `Error` as fill under white | **4.06:1** | Under a 12pt caption. |

Fixed by splitting fill from on-surface text (`accent` vs `accentStrong`, and so
on), deepening the four fills that carry white until white clears 4.5:1, and
keeping `Warning` and `XP` bright with a dark `onWarning` foreground instead,
because deepening gold far enough for white turns it brown.

| Item | Acceptance criteria | Status |
|---|---|---|
| Fill / on-surface token split | Every brand and state colour has a documented role; a `*Strong` member exists for text and icons; `onAccent` / `onWarning` name what goes on a fill | done |
| Increased-contrast variants | Every token ships four appearances; the Increase Contrast setting has an effect | done (23 pairs x 4 appearances asserted) |
| Contrast enforced at both ends | `gen_colors.py` exits non-zero below 4.5:1; `GjuhaContrastTests` measures the same pairs on resolved runtime colours | done (script and runtime agree to 3 decimal places) |
| Overlay tints tokenised | No `Color.white.opacity(...)` left on an adaptive surface; card edges, tracks, chips and option borders visible in light appearance | done (40 call sites across 6 views) |
| 4pt grid codified | `GjuhaSpacing` named steps, radii, 44pt hit target; asserted on the grid | done |
| Button styles | Primary / secondary / card; press feedback; gradient stop opaque so it keeps its measured ratio | done (replaced 4 hand-built copies) |

The script and the test are deliberately redundant. The script alone proves
nothing, because the asset catalog can be edited in Xcode without running it. The
measured agreement between the two is the only reason either claim is worth
anything. Verified by mutation: raising the test floor to 25:1 produces failures
quoting the real runtime numbers.

### Native tab bar

The custom floating capsule bar was replaced with `TabView` + `Tab`. Three
defects, not a matter of taste:

1. **Tab state was destroyed on every switch.** The bar drove a `switch` inside a
   `ZStack` carrying `.id(selectedTab)`, so leaving Words discarded its search
   text, CEFR filter and scroll position. Apple's tab-bar guidance is explicit
   that a section keeps state independently of selection.
2. **The selected label failed contrast.** The capsule was a hardcoded black
   gradient in both appearances with the selected item tinted accent, which is
   about 3.3:1 behind an 11pt semibold label.
3. **It reimplemented system behaviour**: Liquid Glass, the scroll-edge effect,
   iPad sidebar adaptation for a universal app, tab-bar minimise, and VoiceOver
   position reporting.

| Item | Acceptance criteria | Status |
|---|---|---|
| Native tab bar | Per-tab state survives a round trip; iPad adapts to a sidebar; existing UI tests still find each tab by label | done (6 pre-existing UI tests pass unchanged) |

### Launch

The splash was held for a fixed 1.45s whether or not the app was ready, which is
the branded launch delay Apple's launch guidance calls out. It now tracks
`AppFeature.State.isReadyForFirstScreen`, with a short floor so a warm launch does
not strobe and a 2.5s cap so a content failure cannot trap the learner behind it.

| Item | Acceptance criteria | Status |
|---|---|---|
| Readiness-driven splash | Dismisses when the curriculum is in state, not on a timer; capped; Reduce Motion path shortened further | done |

### The daily goal loop

The learner picked a daily goal during onboarding, it was persisted, it was
editable in Profile, and **nothing in the app ever showed progress against it**.
There was no way to know whether today counted.

| Item | Acceptance criteria | Status |
|---|---|---|
| Daily XP accounting | Day-stamped, so the rollover is a read-time comparison and needs no timer, no background task and no assumption that the app was open at midnight; follows the device across time zones like the streak does | done (7 unit tests incl. rollover and reset) |
| Goal derived from the chosen minutes | One rate constant, so the four options cannot drift apart; reachable by reviewing alone, so a learner is never pushed past unretained material to fill a ring | done |
| Surfaced on Home, in Profile, in the widget | Ring in the header, full bar in Profile, ring on the small widget and a capacity gauge on the circular accessory when nothing is due | done (1 UI test) |
| Goal-met is announced once | The session that crosses the line says so; later sessions that day do not | done (goal state read before XP is banked) |

### Achievements

| Item | Acceptance criteria | Status |
|---|---|---|
| Achievement catalogue | 12 milestones over streak, lessons, XP, breadth and mastery; pure evaluation over `UserStats`, no clock and no randomness | done (13 unit tests) |
| Mastery milestones are honest | Read `wordsMastered` from the scheduler, so "100 kept" means survived to the documented long-term interval, never "seen once" | done (asserted: 4,000 words seen with none mastered unlocks no mastery badge) |
| Durable unlock ledger | An unlock is a historical fact and is never recomputed downward, so a broken streak does not take the badge back | done (9 unit tests) |
| Celebrated exactly once | Tracked separately from the ledger, so a celebration survives the app being killed between earning and seeing it | done |
| Surfaced | Grid in Profile with a "next up" row showing real distance; new badges on the completion screen | done (1 UI test: fresh account starts locked) |

### Session summary

The completion screen showed XP and a "best combo" that was really `combo` at the
final question, so a learner who slipped on the last answer was told their best
combo was 0. It now reports accuracy, question count, the true best combo and the
streak, and the screen scrolls with the action pinned, because at accessibility
text sizes the two `Spacer()`s pushed Continue off the bottom with no way to reach
it.

| Item | Acceptance criteria | Status |
|---|---|---|
| Accuracy tracking | Correct and answered counted per attempt; near miss counts as answered, not correct, matching how it is graded and scheduled | done |
| Best combo | Tracked as a maximum rather than read at the end | done |
| Pre-upgrade sessions still resume | Both stored payloads that gained fields decode a previous-version payload with defaults rather than throwing | done (4 unit tests) |
| Reachable at every text size | Scroll view with the action in a bottom safe-area inset | done |

### Stored-payload compatibility

Two persisted structs gained fields after 1.0 was already installable, and
synthesised `Codable` throws on a payload missing a non-optional key. Both failure
modes are silent: a learner mid-lesson loses their place, and a placed widget
falls back to its placeholder. Both now decode with defaults, and the tests build
their fixtures by encoding a real value and deleting the new keys, rather than
hand-writing a payload that would drift from the schema and then test nothing but
itself.

### Fifth sub-pass: HIG design audit

Audited against Apple's Human Interface Guidelines after the colour work landed.
The audit found one thing the previous pass got wrong and three it had not
reached.

**What the previous pass got wrong.** `GjuhaContrastTests` measured every text
token against `surface` and `background`, and the cards do not draw on either:
they drew on `.ultraThinMaterial` over an animated gradient, so the background
actually behind the text was neither of the two surfaces the guarantee was proven
against. The guarantee had a hole in it.

| Item | Acceptance criteria | Status |
|---|---|---|
| Reduce Transparency has an answer | No material or tint survives the setting, at any prominence, with Increase Contrast on or off | done (8 unit tests; mutation verified) |
| Text-bearing surfaces use a thicker material | `.regularMaterial`, not `.ultraThinMaterial`, so the measured contrast describes something closer to what renders | done (32 card call sites, 5 control fills) |
| Material is not stacked on material | A surface drawn inside another surface carries a tint and no shadow | done (`.nested` prominence) |
| The modifier says what it draws | `gjuhaLiquidGlassCard` renamed to `gjuhaCardSurface`; `GjuhaLiquidGlassBackground` to `GjuhaAmbientBackground` | done |
| Hit targets meet the platform floor | The lesson exit button and the CEFR filter pill were roughly 17pt and 24pt tall against a 44pt default and a 28pt minimum | done |
| Layout adapts by size class | Profile splits into two columns at regular width; cap widens 620 to 1040 | done |
| Title casing is consistent | "Lesson Complete!" was the only title-case string in an app that is sentence case throughout; Albanian carried over to the new key | done |

The naming mattered more than it looks. Apple's model has a content layer and a
functional layer of controls floating above it, and Liquid Glass belongs only to
the second: in the content layer it "can result in unnecessary complexity and a
confusing visual hierarchy". Every one of these surfaces is content, so none was
ever a candidate for glass, and the old name told every future reader otherwise.
The app's real functional layer is the tab bar and navigation bar, which get the
material from the system now that the custom bar is gone.

`GjuhaSurfaceStyle.resolve` is a pure function for a specific reason: a
`ViewModifier` cannot be inspected from a unit test, so leaving the fallback
inside the modifier would have made it a comment with nothing behind it. Verified
by mutation: disabling the Reduce Transparency branch fails
`reduceTransparencyLeavesNothingTranslucent` and
`anOpaqueNestedSurfaceStillSeparatesFromItsParent` with the expected messages.

### Sixth sub-pass: platform conventions, performance, and the iPad gap

Three findings the colour and surface work had not reached.

**The app was never run on iPad, and its own test suite failed there.** It ships
as a universal app with `TARGETED_DEVICE_FAMILY: "1,2"`, and every UI test
located a destination with `app.buttons["Words"]`. On iPad the system publishes
each tab button twice, as a wrapper and the button inside it, so that subscript
is ambiguous: the element reports as existing and never becomes hittable. Four of
eight UI tests failed, with a message ("existed but never became tappable") that
describes the symptom and not the cause. Fixed by resolving `.firstMatch` through
a helper that also accepts the sidebar presentation, since the two are the same
destination.

**A `WKWebView` per mascot.** `AnimatedMascotView` base64-encoded the 1.2 MB
mascot GIF into an HTML document and handed it to a web view to play. Each
instance started an out-of-process web content renderer; Grammar and Words each
place two, so browsing vocabulary could run several at once to show a looping
badge. It also linked WebKit into an app that has no web content. Replaced with
`CGAnimateImageDataWithBlock`, which is the API for this: it decodes on demand
and honours the GIF's own frame delays, so memory stays at a frame or two instead
of the 25 MB that holding all 37 frames of a 420x420 loop would cost. WebKit is
no longer linked.

**Neither Home nor Profile adapted to width.** The app had no `horizontalSizeClass`
branch anywhere; its only width behaviour was a 620pt reading cap, so an iPad
showed a phone column centred in a wide window.

| Item | Acceptance criteria | Status |
|---|---|---|
| UI suite passes on iPad | All 8 UI tests green on a 13" iPad at the iOS 26.5 deployment floor | done (verified, 213s) |
| Mascot animates without WebKit | No WebKit symbol in the app; animation verified running, not assumed | done (3 unit tests; runtime pixel-delta measured) |
| Home adapts to width | Context rail and lesson map in two columns at regular width | done (runtime verified on iPad) |
| Profile adapts to width | Progress and settings in two columns at regular width | done |
| CI enforces the contrast floor | The generator runs and a diff fails the build, so the catalog cannot be hand-edited past the floor | done |
| Press feedback everywhere | 15 further controls moved off `.buttonStyle(.plain)` | done |
| Token roles correct outside the screens already audited | 9 fill tokens used as a foreground moved to their on-surface member | done |
| Hit targets | The vocabulary play button (34pt) joined the lesson exit button and the filter pill | done |
| Vocabulary rows are one VoiceOver stop | A 350 word list was three or four swipes per row | done |

The mascot animation is verified rather than asserted. A unit test cannot drive
it: `CGAnimateImageDataWithBlock` schedules on a run loop a test does not spin, so
awaiting the stream hangs instead of failing. The tests cover what is
deterministic (the asset is a multi-frame GIF that Image I/O decodes end to end),
and the animation itself was measured on a running simulator: successive
screenshots differ by a mean absolute pixel delta of 17.6 to 25.8 in the mascot
region against 2.4 to 4.7 in a background-only region, so the movement is the
mascot and not the ambient drift.

### Not done in this pass

- Albanian for the 51 new strings is entered and marked `needs_review`, like every
  other Albanian entry. Still the same open gate.
- `xpPerMinute = 12` is a judgement from what the engine awards, not a measurement
  against real learners. Recorded in `APP_STORE_SUBMISSION.md` section 9.
- The widget's install-over-an-older-build path is unit tested but not device
  verified. Added to the device checklist.
- Increase Contrast now has an effect for the first time, which means it has never
  been looked at on hardware. Added to the device checklist.
- **Contrast over a material is still not measured.** The cards now use the
  regular material rather than the thinnest one, and Reduce Transparency makes
  them fully opaque, so the measured token-versus-surface ratios describe the
  opaque path exactly and the translucent path closely. A SwiftUI `Material`
  cannot be resolved to a colour from a unit test, so the translucent path is
  reasoned about rather than measured. Checking it needs a screenshot on hardware,
  in both appearances, which is on the device checklist.
- **Home keeps a single column at regular width.** Profile splits because its
  sections are independent; the lesson map is one vertical flow and reads correctly
  centred. Putting the next-unit and culture cards in a side rail at regular width
  is a sensible next step and was not done here.

## Verification log

See `VERIFICATION.md` for build, test, and simulator runtime evidence.
