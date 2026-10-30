# Remaining Work

Everything not done, in one place, with who can actually do it. Written after the
design and retention passes so that "what is left before 1.0" has a single
answer instead of being spread across four documents.

Status of the tree as this was written: build clean with no warnings, 149 unit
tests in 19 suites and 8 UI tests passing on an iPhone and on a 13" iPad at the
iOS 26 deployment floor, 65 Kotlin tests for the Android domain, localization
and seed checks clean, every measured colour pair at or above 4.5:1.

The sections are ordered by who is blocked. Nothing in section 1 can be
unblocked by writing code, and within it the hard blockers are separated from the
quality gates, because only the first group actually stops a submission.

---

## 1. Blocked on a human

Nothing here can be unblocked by writing code. Two kinds, and the distinction
matters: the first three stop a submission, the last two do not.

### Hard blockers: all three are now closed

App Store Connect will not accept a submission without these. They are listed
because they were the gate, and so the record shows what closed them.

| Item | What it needs | Who |
|---|---|---|
| **Privacy policy URL** | **Done and live** at `https://gjuha.peterdsp.dev/privacy.html`, HTTP 200 over a valid certificate. Every claim was checked against the code. | Closed |
| **Support URL** | **Done and live** at `https://gjuha.peterdsp.dev/support.html`. | Closed |
| **Screenshots** | **Done and populated.** `bash Scripts/capture_screenshots.sh` plays the opening lesson and writes seven 1320 x 2868 captures. Nothing is seeded: the exercises are solved from the shipped vocabulary and answered through the real interface, so the 97 XP, the 100% accuracy and the First steps badge were earned. Every figure agrees across Home, Profile and the completion screen. | Closed |

**All three hard blockers are closed.** The pages are live on the branded
domain, and the screenshots are generated and populated. Nothing now stands
between this tree and an App Store submission except the two quality gates
below, both of which need a person rather than code.

### Quality gates: App Review would pass the app without them

Neither of these is a compliance requirement. Both are recorded because shipping
without them carries a real risk that no automated check can see.

| Item | What it needs | Why it is here |
|---|---|---|
| **Albanian interface strings** | A native speaker reads the 223 strings (203 app, 20 widget) and clears the `needs_review` state. | App Review will not catch this. But for an app whose premise is teaching Albanian, shipping Albanian chrome that no Albanian speaker has read is a credibility risk. The achievement titles matter most: "Halfway to fluent" and "Three in a row" are idioms that translate badly word for word. |
| **Device pass** | The checklist in `APP_STORE_SUBMISSION.md` section 8: widgets in every family, the four Siri phrases, a VoiceOver drive-through, Increase Contrast, Reduce Transparency, and the Albanian locale. | Widgets, Siri and VoiceOver have never run on hardware; only the data paths beneath them are unit tested. "The deep link is correct" is not "tapping the widget opens the right screen." |

---

## 2. Known limits, recorded rather than fixed

Real, understood, and deliberately not addressed. None blocks release.

**Contrast over a material is reasoned about, not measured.** The palette's
ratios are computed against opaque surfaces, and `GjuhaContrastTests` asserts them
against the colours the app resolves. Cards render `.regularMaterial` over a
gradient, and a SwiftUI `Material` cannot be resolved to a colour from a test.
Reduce Transparency makes every surface opaque, so that path is exact; the
translucent path is close but unproven. One screenshot per appearance on hardware
settles it.

**The mascot animation is verified by measurement, not by a test.**
`CGAnimateImageDataWithBlock` schedules on a run loop a unit test does not spin,
so awaiting its stream hangs rather than failing. The tests cover the asset
decoding end to end; the animation itself was confirmed on a running simulator by
pixel delta (17.6 to 25.8 in the mascot region against 2.4 to 4.7 in a
background-only region).

**`xpPerMinute = 12` is a judgement.** The daily goal is derived from it, so all
four goal options move together if it is wrong, but it has never been checked
against how long real learners take. One constant to change.

**Pronunciation audio ships with zero reviewed assets.** The infrastructure,
manifest, gating and player are all present and listening exercises degrade
cleanly. Unblocking needs either Azure Neural TTS `sq-AL` billing authorization or
native recordings, then native review of every clip.

**Gheg dialect pack and the hospitality cultural unit** stay
`pendingNativeReview` and are held out of production by `ContentCatalog`. The
learner-facing flows are wired and gated; the content is what is missing.

**Grammar coach output stays English.** `CoachExplanation.text` and its
disclaimer are generated prose, deliberately not localized: translating the
disclaimer while the explanation stays English would be worse than leaving both.
If it is ever localized, both go together.

**The achievement "earned while you were away" surface does not exist.**
`AchievementStore.uncelebrated` is implemented and tested, and nothing reads it:
the completion screen is told directly which badges a session earned. It is there
so a future surface has a correct answer available, rather than being an untested
promise.

---

## 3. Android

Not a release gate for the iOS app, and recorded here because "the same app on
both platforms" is the stated goal and it is now underway rather than
hypothetical.

**What exists.** `android/core` is a plain Kotlin library holding the whole
learning domain, ported with parity tests asserting the same facts the Swift
suite does: answer grading including the rule that Albanian diacritics are
required, the SM-2 scheduler with its ease bounds and its 21 day mastery
threshold, the daily XP goal and its read-time rollover, the achievement
catalogue with ids matching iOS exactly because they are persisted, and the
exercise engine including the distractor rules that keep a question answerable.
65 Kotlin tests, run with `./gradlew :core:test` under OpenJDK 21.

**Content is not duplicated.** The Kotlin tests read the same seed under
`Gjuha/Data/Seed/` that the iOS app ships, and assert the figures
`validate_seed.py` prints. The Android app will copy that seed into assets
rather than keep a second copy, so a word cannot say one thing on iPhone and
another on Android.

**What does not exist yet.** The Android app module and its Compose UI. That is
the larger remaining half by volume, though the smaller by risk: the rules that
are hard to get right and expensive to get wrong are the ones already ported and
under test.

**One known divergence, deliberately not papered over.** `LessonVocabulary`
derives a lesson's words from the seed, while iOS keeps an explicit 120 entry
table in `ExerciseEngine`. These are different rules, so the tests assert only
what is true of both: every lesson gets words, none are orphaned, the mapping is
stable. Making them identical means moving the iOS table into the seed, which is
the right next step.

---

## 4. Product roadmap, not release work

From the README roadmap, unchanged by these passes.

**Phase 2, content depth.** Full A1 curriculum at 30 lessons; verb conjugation
and noun case exercise types; the grammar reference module; audio.

**Phase 3, engagement.** Cultural immersion modules. Spaced repetition, streaks,
the daily goal, notifications and achievements are done.

**Phase 4, scale.** A2 curriculum; downloadable content packs; accounts and sync;
Gheg dialect mode.

Two smaller ideas worth recording while they are fresh:

- **A streak at risk warning.** The streak can break silently. Nothing tells a
  learner late in the day that today is still empty. The daily goal ring now makes
  the state visible when the app is open, and the widget shows it on the Home
  Screen, so this is less urgent than it was, but a notification that fires only
  when the goal is unmet would close it.
- **Home at regular width still has an empty lower rail.** The context column ends
  well above the fold on a 13" iPad while the map column runs long. Something
  belongs there: recent words, or the next achievement.

---

## What has been closed

Zero hard blockers remaining, two quality gates. For contrast, the items that
were open before these passes and are not any more: the daily goal loop had no surface at all; achievements did not
exist; there was no Reduce Transparency answer anywhere; the palette had no
increased-contrast variants; the tab bar was custom and lost each tab's state; the
splash was held on a fixed timer; the app had never been run on iPad and four of
its UI tests failed there; and the mascot was animated by a web view.

Detail for each is in `COMPLETION_LEDGER.md`, fourth pass onward.
