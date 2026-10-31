# Releasing the Android app

What the build already does, and the two things only the owner can do.

---

## What is configured

`android/app/build.gradle.kts` reads release signing from
`android/keystore.properties`, which is gitignored, as are `*.jks` and
`*.keystore`. **No key, and no detail of a key, is in this repository.**

If that file is absent the release build still succeeds and produces an
unsigned APK, so CI and anyone without the key can build and verify the app.
Only the holder of the key can produce something installable.

Release builds are shrunk with R8 (`isMinifyEnabled`, `isShrinkResources`).
The rules in `app/proguard-rules.pro` are load bearing rather than
decorative: the learning domain is reached through kotlinx-serialization's
generated serializers, which R8 cannot see from the call sites. Without them
the app builds cleanly and then fails the first time it reads the seed, which
is on the launch path.

Shrinking takes the APK from about 10 MB to about 2.4 MB.

---

## Creating the signing key

This is yours to create and yours to keep. Losing it means never being able to
update the app under the same listing again, so back it up somewhere that is
not this machine.

```sh
keytool -genkeypair -v \
  -keystore ~/keys/gjuha-release.jks \
  -alias gjuha \
  -keyalg RSA -keysize 2048 -validity 10000
```

Then create `android/keystore.properties`, which git ignores:

```properties
storeFile=/Users/you/keys/gjuha-release.jks
storePassword=...
keyAlias=gjuha
keyPassword=...
```

Consider enrolling in Play App Signing, where Google holds the app signing key
and you hold only an upload key. It makes a lost key recoverable.

---

## Building

```sh
cd android
./gradlew :app:bundleRelease    # app-release.aab, what Play wants
./gradlew :app:assembleRelease  # app-release.apk, for installing directly
```

Outputs land in `app/build/outputs/bundle/release/` and
`app/build/outputs/apk/release/`.

Check the signature before uploading:

```sh
$ANDROID_HOME/build-tools/35.0.0/apksigner verify --print-certs \
  app/build/outputs/apk/release/app-release.apk
```

---

## Verifying a release build before it ships

A release build is not a debug build with a different name. R8 can remove
something the app reaches only by reflection, and the failure shows up at
runtime rather than at compile time. So run it:

```sh
adb install -r app/build/outputs/apk/release/app-release.apk
python3 Scripts/android/play.py          # plays a whole lesson
```

Playing a lesson is the useful check because it exercises what shrinking most
endangers: decoding the bundled seed, generating exercises, and serializing
the resumable session. A build that launches but cannot read the seed shows an
empty course rather than crashing, which is easy to miss.

This was last done on the shrunk, signed build: it completed a lesson for
72 XP and the profile then read 72 total, ten words seen, one lesson done, ten
in review and none mastered.

Screenshots for the listing: `python3 Scripts/capture_android_screenshots.py`,
which plays the app rather than seeding it.

---

## What is left, and who can do it

| Item | Who |
|---|---|
| Create and back up the signing key | Owner |
| Play Console listing: title, description, graphics, content rating, data safety | Owner |
| Albanian strings read by a native speaker | A native speaker, the same pass as iOS |

The data safety form is short for this app: it collects nothing, sends nothing
off the device, and requests no permissions. `AndroidManifest.xml` declares no
`uses-permission` at all, deliberately, so that adding one is a visible
decision rather than something that creeps in.

---

## Play Console listing

Edit for voice. It is accurate as written, which matters more than it sounds:
the iOS description claims things the Android build does not have, so it
cannot be copied across. Android has no Siri, no on-device grammar generation,
and no dialect or cultural content. Claiming any of them here would be a
false listing, not a rounding error.

Character limits are Play's.

**App name** (30): `Gjuha: Learn Albanian`

**Short description** (80):
> Albanian that sticks. Spaced repetition, honest progress, fully offline.

**Full description** (4000):
> Albanian has no Duolingo course. Gjuha is built for adults who want to
> actually remember what they study, not collect streak badges.
>
> SPACED REPETITION THAT DOES THE REMEMBERING FOR YOU
> Every word you learn enters a review schedule. Gjuha brings it back at
> widening intervals and prioritises the words you keep getting wrong, so your
> study time goes where it is needed rather than where it feels comfortable.
>
> PROGRESS YOU CAN TRUST
> Most apps treat "seen once" as "learned". Gjuha keeps three separate figures:
> words seen, words in review, and words mastered. Mastered means a word has
> survived to a documented long-term interval. Nothing else is presented as
> mastery.
>
> SPELLING THAT IS CORRECTED, NOT WAVED THROUGH
> Albanian uses e and c with diacritics, and they change meaning. Type a word
> without them and Gjuha tells you which letters are missing instead of
> accepting it or marking you simply wrong.
>
> A REAL COURSE, NOT A WORD LIST
> Twelve units and a hundred and twenty lessons, from survival basics to B1,
> with matching, multiple choice, word order, typing and fill the blank drawn
> from a vocabulary of three hundred and fifty four words.
>
> GRAMMAR EXPLAINED, NOT JUST DRILLED
> Clear grammar guides with conjugation tables and real examples, including how
> Albanian puts its definite article on the end of the noun.
>
> WORKS ENTIRELY OFFLINE
> No account, no servers, no analytics, no ads, no subscriptions. The app
> requests no permissions at all. Everything lives on your device.
>
> HOME SCREEN WIDGET
> Your streak, what is due for review, and the next lesson at a glance.

**Category**: Education. **Tags**: Language learning, Education.

**Contact**: `info@peterdsp.dev`
**Privacy policy**: `https://gjuha.peterdsp.dev/privacy.html`
**Support**: `https://gjuha.peterdsp.dev/support.html`

### Data safety form

Short, because the app does none of it:

| Question | Answer |
|---|---|
| Does your app collect or share any required user data? | No |
| Is all user data encrypted in transit? | Not applicable, no data leaves the device |
| Do you provide a way for users to request data deletion? | Yes, in the app. It never leaves the device, and Profile clears it |

The manifest declares no `uses-permission` at all, so the permissions section
is empty. That is deliberate: adding one should be a visible decision rather
than something that creeps in.

### Content rating

Answer the questionnaire honestly and it lands at the lowest rating. The app
has no violence, no user-generated content, no social features, no purchases,
no ads, and no data collection. The only text a learner sees is Albanian
vocabulary and grammar.

### What is still missing before this can be submitted

- The signing key, above.
- Screenshots: `python3 Scripts/capture_android_screenshots.py` writes seven
  at 1080x2400. Play wants at least two.
- A feature graphic at 1024x500. Nothing in this repository generates one.
- The Albanian interface strings read by a native speaker, which is the same
  gate iOS is waiting on and is covered once for both platforms. See
  REVIEW_PACKAGE.md.
