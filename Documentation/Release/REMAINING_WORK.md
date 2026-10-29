# Remaining Work

Everything not done, in one place, with who can actually do it. Written after the
design and retention passes so that "what is left before 1.0" has a single
answer instead of being spread across four documents.

Status of the tree as this was written: build clean with no warnings, 142 unit
tests in 18 suites and 8 UI tests passing on an iPhone and on a 13" iPad at the
iOS 26 deployment floor, localization and seed checks clean, every measured
colour pair at or above 4.5:1.

The three sections are ordered by who is blocked. Nothing in section 1 can be
unblocked by writing code.

---

## 1. Blocked on a human, and blocking release

These are the only items that stand between the current tree and submitting.

| Item | What it needs | Who |
|---|---|---|
| **Albanian interface strings** | A native speaker reads the 226 strings (205 app, 21 widget) and clears the `needs_review` state. They are UI chrome, not teaching content, so the risk is low, but "low" is not "checked". | Native speaker |
| **Privacy policy and support URLs** | Two reachable URLs on a domain you control. Draft policy text is in `APP_STORE_SUBMISSION.md` section 3 and is accurate as written. | Account holder |
| **Screenshots** | 6.9" iPhone required, 13" iPad strongly recommended. The six to take, in order, are listed in `APP_STORE_SUBMISSION.md` section 7. | Account holder |
| **Device pass** | The checklist in `APP_STORE_SUBMISSION.md` section 8. Widgets in every family, Siri phrases, a VoiceOver drive-through, Increase Contrast, Reduce Transparency, and the Albanian locale. | Account holder, on hardware |

The achievement titles deserve the most attention in the Albanian pass. Several
are idiomatic in English ("Halfway to fluent", "Three in a row") and a literal
translation will read oddly.

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

## 3. Product roadmap, not release work

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

For contrast with the above, the items that were open before these passes and are
not any more: the daily goal loop had no surface at all; achievements did not
exist; there was no Reduce Transparency answer anywhere; the palette had no
increased-contrast variants; the tab bar was custom and lost each tab's state; the
splash was held on a fixed timer; the app had never been run on iPad and four of
its UI tests failed there; and the mascot was animated by a web view.

Detail for each is in `COMPLETION_LEDGER.md`, fourth pass onward.
