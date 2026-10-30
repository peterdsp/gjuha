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
