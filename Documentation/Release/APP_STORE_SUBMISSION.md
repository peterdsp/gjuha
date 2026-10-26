# App Store Submission

Everything needed to put Gjuha 1.0.0 in front of App Review, and the things only
the account holder can do. Written to be followed in order.

Nothing in here claims work is done that is not. Items marked **you** need a human
with account access; items marked **repo** are already in the tree.

## 1. Build identity

| Item | Value | Where |
|---|---|---|
| Bundle identifier | `com.gjuha.app` | `project.yml` |
| Widget bundle identifier | `com.gjuha.app.widgets` | `project.yml` |
| Marketing version | `1.0.0` | `project.yml`, both targets |
| Build number | `1` | `project.yml`, both targets |
| Minimum iOS | **27.0** | `project.yml` |
| Device families | iPhone and iPad | `TARGETED_DEVICE_FAMILY: "1,2"` |

The app and the widget must always carry the same `CFBundleShortVersionString` and
`CFBundleVersion`. App Review rejects a bundle whose extension version does not
match the host app, and because both are generated from `project.yml` they can
only drift if someone edits one of the two blocks.

### The iOS 27 floor is a deliberate, costly choice

Raising the deployment target to 27.0 means only devices on the newest major iOS
can install Gjuha. That is a very small install base at launch, and it cuts
directly against the diaspora audience described in `RESEARCH.md`, who are the
most likely to be on older hardware. It was chosen explicitly over the wider
reach of an iOS 17 or iOS 18 floor. Nothing in the codebase requires it: the
widget and the App Intents work on iOS 17, and the few iOS 26+ App Intents APIs
in use (`supportedModes`, `allowedExecutionTargets`) can be availability gated.
Lowering the floor later is a `project.yml` change plus availability annotations,
and it does not touch feature code.

## 2. Capabilities to enable before archiving (**you**)

1. **App Groups.** In the Apple Developer portal, enable App Groups for both
   `com.gjuha.app` and `com.gjuha.app.widgets`, and add the group
   `group.com.gjuha.app` to each. The entitlement files are already in the repo
   (`Gjuha/Gjuha.entitlements`, `GjuhaWidgets/GjuhaWidgets.entitlements`).
   If this is skipped, the app still works and the widget falls back to its
   placeholder: no learner data is lost, because the App Group carries only a
   derived projection (see `Gjuha/Shared/GjuhaWidgetSnapshot.swift`).
2. **Set `DEVELOPMENT_TEAM`.** It is empty in `project.yml`, so an archive will
   fail to sign. Put your Team ID there, or set it in Xcode's signing editor and
   keep `project.yml` in step.
3. No push notifications, no Sign in with Apple, no background modes, no
   HealthKit. The daily reminder uses local notifications, which need no
   capability.

## 3. App Privacy answers

Gjuha performs no network requests, links no third-party SDKs, and has no backend
or account system. Everything the learner produces stays in the app container.

- **Data collection: "No, we do not collect data from this app."** Every category
  in App Store Connect's questionnaire is therefore "Not Collected".
- **Tracking: No.** No ATT prompt is presented.
- This matches `Gjuha/Resources/PrivacyInfo.xcprivacy`, which declares
  `NSPrivacyTracking: false`, no collected data types, and one required-reason
  API: `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` (the app
  reads and writes only its own defaults and its own App Group suite).

If a network call, analytics SDK, or account system is ever added, the manifest
and these answers must change in the same commit as the code.

### Privacy policy and support URLs (**you**)

App Store Connect requires a reachable privacy policy URL, and a support URL. Both
have to be hosted somewhere you control. A privacy policy for this app is short
and can say, accurately:

> Gjuha stores your learning progress only on your device. It has no servers, no
> accounts, and no analytics, and it sends no data anywhere. Progress can be
> deleted at any time from Profile, with "Reset learning data". Local
> notifications, if you turn on the daily reminder, are scheduled on your device
> and contain no personal data.

## 4. Export compliance

`ITSAppUsesNonExemptEncryption` is set to `false` in `project.yml`, so uploads are
not held for an encryption question each time. This is accurate: the app uses no
cryptography beyond what iOS itself provides, and makes no network connections at
all.

## 5. Age rating

Expect **4+**. There is no user-generated content, no social features, no web
views, no ads, no purchases, and no mature content. Answer "None" to every
frequency question. The grammar coach, when the on-device model is available,
generates grammar explanations only and is grounded in the lesson content: it has
no open chat surface.

## 6. Metadata draft

The account holder should edit this for voice, but it is accurate as written.
Character limits are App Store Connect's.

**App name** (30): `Gjuha: Learn Albanian`

**Subtitle** (30): `Remember what you study`

**Promotional text** (170):
> Albanian, built to stick. A spaced repetition schedule brings every word back
> exactly when you are about to forget it, and your progress is honest about what
> you have actually mastered.

**Keywords** (100, comma separated, no spaces):
`albanian,shqip,learn albanian,language,vocabulary,spaced repetition,flashcards,grammar,kosovo,diaspora`

**Description**:
> Albanian has no Duolingo course. Gjuha is built for adults who want to actually
> remember what they study, not collect streak badges.
>
> **Spaced repetition that does the remembering for you**
> Every word you learn enters a review schedule. Gjuha brings it back at
> widening intervals, prioritising the words you keep getting wrong, so your
> study time goes where it is needed instead of where it feels comfortable.
>
> **Progress you can trust**
> Most apps conflate "seen once" with "learned". Gjuha keeps three separate
> figures: words seen, words in review, and words mastered. Mastered means a word
> has survived to a documented long-term interval, and nothing else is presented
> as mastery.
>
> **Standard Albanian, with regional forms labelled honestly**
> The course teaches Standard Albanian. Where a Gheg form is common, it is shown
> as a labelled regional variant, never as a mistake, because usage varies by
> region and family.
>
> **Grammar explained, not just drilled**
> Transparent grammar guides with conjugation tables and real examples. On
> supported devices, a tailored explanation can be generated on device; when it
> cannot, you get an offline explanation built from your own reviewed lessons.
> Either way, explanation is kept strictly separate from grading.
>
> **Works entirely offline**
> No account, no servers, no analytics, no ads, no subscriptions. Everything
> lives on your device, and you can delete all of it in one tap.
>
> **Home Screen and Lock Screen widgets**
> See your streak, what is due, and the next lesson at a glance. Ask Siri to
> start your review or check your progress.

**What's New in 1.0.0**: first public release, so leave this empty or write
"First release."

**Copyright**: `2026 Petros Dhespollari`

**Category**: Primary `Education`, secondary `Reference`.

## 7. Screenshots (**you**)

Required: 6.9" iPhone. Strongly recommended: 13" iPad, since the app ships an
iPad-tailored layout and is listed as a universal app.

Suggested six, in this order, because they tell the differentiator story rather
than just showing screens:
1. Home with the lesson map and a visible streak.
2. The Daily review card with words due.
3. A review question mid-answer.
4. Profile, showing words seen / in review / mastered side by side.
5. A grammar guide with its conjugation table.
6. The Home Screen widget beside the app.

Do not screenshot the culture or dialect screens: their content is still gated on
native review and in a normal build they show an "in review" empty state.

## 8. Pre-flight checklist

Run from a clean checkout:

```sh
xcodegen generate
python3 Scripts/validate_seed.py
xcodebuild test -project Gjuha.xcodeproj -scheme Gjuha \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skipMacroValidation -only-testing:GjuhaTests
xcodebuild test -project Gjuha.xcodeproj -scheme Gjuha \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skipMacroValidation -only-testing:GjuhaUITests
```

`-skipMacroValidation` is needed because TCA's macros are trusted through the
Xcode GUI, which a CLI build does not have. CI runs all of the above plus a check
that the committed `project.pbxproj` matches `project.yml`.

Then, by hand on a device:
- [ ] Widget added to Home Screen, shows real numbers, tapping it opens the right
      screen.
- [ ] Lock Screen widget in all three accessory families.
- [ ] "Hey Siri, start my review in Gjuha" with words due, and with none due.
- [ ] The four App Shortcuts appear in the Shortcuts app.
- [ ] VoiceOver drive-through of onboarding, a lesson, and Profile. This is the
      one accessibility check that still needs a real device (see the
      `COMPLETION_LEDGER.md` note).
- [ ] Albanian locale: switch the device to Albanian and confirm the UI, then
      see the native review gate in section 9.

## 9. Open gates before 1.0 ships

These are real and are not closed by this pass.

1. **Albanian UI strings need a native pass.** All 170 on-screen strings are now
   in String Catalogs with an Albanian locale, but every Albanian entry is marked
   `needs_review` in the catalog. They are UI chrome only (buttons, labels,
   settings), not teaching content, so the risk is low, but they have not been
   checked by a native speaker. See `REVIEW_PACKAGE.md` section 4.
2. **Pronunciation audio.** Still zero reviewed assets. Needs billing
   authorization for Azure Neural TTS `sq-AL`, or native recordings, then native
   review of every clip. Listening exercises degrade cleanly today.
3. **Gheg dialect pack and the hospitality cultural unit.** Still
   `pendingNativeReview`, still held out of production by `ContentCatalog`.
4. **Grammar coach output stays English.** `CoachExplanation.text` and its
   disclaimer are generated English prose and are deliberately not localized:
   translating the disclaimer while the explanation stays English would be worse
   than leaving both. If the coach is ever localized, do both together.
