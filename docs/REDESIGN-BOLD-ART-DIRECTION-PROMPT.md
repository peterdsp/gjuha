# Prompt: a bold new art direction for Gjuha

Hand this whole file to an agent session opened in the Gjuha repo. It mirrors the bold
redesign done for the sibling products Nostavela and Odivrelo, adapted to Gjuha's reality:
a native app, not a web app. Keep the house rules from the global guide and this repo's
CLAUDE.md: no em-dash anywhere, no AI references or attribution in commits, PRs or docs,
English as the base language, minimal diffs, TCA feature pattern preserved, and no
autonomous destructive git actions.

---

You are redesigning Gjuha with a completely new, bold visual identity. Gjuha is an
offline-first, iOS-native Albanian language learning app (A1 to B2), built in SwiftUI with
The Composable Architecture and SwiftData, with a Kotlin/Compose Android app alongside, plus
widgets and App Intents. It is a gamified learning experience: XP, streaks and progress are
first-class, and the palette already carries `XP`, `Streak`, `Success`, `Warning`, `Accent`
and their on-surface `*Strong` partners. The audience is the foreign partners of Albanians,
the diaspora reconnecting, expats in Tirana, and language enthusiasts drawn to one of the
oldest Indo-European languages.

## What is different here: this is a native app

The `/design-taste-frontend` skill's scripts (`draw.mjs`, `inspect.mjs`, `assets.mjs`) run
against a browser and HTML/CSS. They do not run against SwiftUI or Compose. So use that skill
for what it is good at on a native app: dealing candidate directions and, above all, finding
the one idea that belongs to this subject and no other (its "find the idea" step). Do not try
to run its inspector against the app. The palette, type and composition decisions are then
expressed in SwiftUI and Compose, and verified the native way (below).

The primary engines for Gjuha are:

1. `/apple-hig` and `/apple-design`: the native iOS design review and decisions. Dynamic
   Type across every text style, 44pt minimum targets, clarity, deference and depth, SF
   symbols used correctly, dark mode and Increase Contrast honoured, motion that respects
   Reduce Motion. Review the lesson flow, the home and progress screens, and the widgets.
2. `/app-intents-specialist`: Gjuha already ships App Intents (`Gjuha/Intents/`). Extend and
   refine them for the core actions (start today's lesson, log a review, show the streak),
   with Shortcuts phrases, a snippet view that matches the new look, and complete behaviour
   when Siri is unavailable.

## Find the idea from Albanian, not from "a language app"

Do the inventory the design skill asks for, drawn from the Albanian language and culture, not
from generic gamified learning. Strong hooks for the art direction:

- **The alphabet itself.** Albanian has 36 letters, including the ones learners notice first:
  `ë`, `ç`, and the digraphs `dh`, `gj` (the app's own name), `ll`, `nj`, `rr`, `sh`, `th`,
  `xh`, `zh`. Let the letterforms, especially `gj`, become the motif: a display face that
  celebrates the diacritics rather than hiding them.
- **Besa and the oath.** The cultural concept of keeping one's word maps onto the streak and
  the daily promise to practise. Make the streak feel like besa, not like a generic flame.
- **The textile and the pattern.** Traditional Albanian weaving and the qeleshe have real
  geometric motifs that can become a considered background system or progress ornament, used
  with restraint, never as wallpaper.
- **The eagle and the highland light.** The double-headed eagle and the colours of the
  Albanian landscape and flag are the obvious national palette. Use their spirit, but decide
  deliberately: a bold identity built only from flag red and black is a cliche. Take the
  dealt direction's proportions and let Albanian material inform the hue.

Fill this sentence before building: "In Gjuha, **[something only Albanian has]** becomes
**[the device the direction calls for]**." Put a generic language app in the sentence; if it
still works, the idea is the category and you must dig again.

## The palette and type (through the real source of truth)

Color in this app has one source: `Scripts/gen_colors.py`, which writes `Palette.xcassets`
and measures contrast, and `GjuhaContrastTests` asserts the same floors against the colors
the app resolves at runtime. So the redesign changes the palette there, not by hand-editing
colorsets. Keep the script's existing discipline exactly:

- Four appearances per token: light, dark, light+high-contrast, dark+high-contrast. Increase
  Contrast must still have an effect everywhere.
- Fill and on-surface are separate roles: the unsuffixed token is the fill, the `*Strong`
  token is the text or icon colour on a surface. White on any fill that carries white must
  still clear 4.5:1; a bright gold fill keeps its dark `OnWarning` foreground rather than
  being deepened to brown.
- Overlay tints stay tokens that invert with appearance (`Hairline`, `GlassTint`, `Track`,
  `ChipFill`, `ControlFill`), never `Color.white.opacity(...)`.

Deal a bold new palette and map it onto these roles. Push the display type larger and more
expressive, with tracking tightened on the big sizes only and body text left at its natural
tracking, and make sure the diacritics (`ë`, `ç`) and digraphs are beautiful at display size.
The gamified elements (XP, streak, progress) should feel crafted and celebratory in the new
look, not stock.

## Invariants (do not break)

- The TCA feature module pattern stays: `@Reducer` state and actions in the feature file,
  views in `Views/`. The redesign touches views, styles and the palette, not the architecture.
- Offline-first holds: no screen depends on the network to render.
- The content engine drives sentences; do not hardcode learning content into views.
- Localization: the app's own languages stay fully covered; no hardcoded English in a view
  that should be localized.

## Deliverable and verification

Apply the new direction across the SwiftUI screens, the widgets and the App Intents snippet
views, and carry the palette and type into the Compose Android app. Then verify, and report
passed, failed and not-run separately:

- `python3 Scripts/gen_colors.py` to regenerate the catalog and print the measured contrast.
- Build and test with xcodebuild (regenerate the project from `project.yml` with xcodegen
  first if the project uses it): run `GjuhaContrastTests` and the snapshot and unit tests,
  and confirm the contrast floors still pass for the new palette.
- Capture Xcode Preview or simulator screenshots of the home, a lesson, the progress screen
  and each widget size, in light, dark and Increase Contrast, and in the app's languages.
- Run the `/apple-hig` and `/apple-design` lenses over those screens and record the Dynamic
  Type, target-size, colour-alone and Reduce Motion findings.
- For Android, build the Compose app and confirm the shared palette and type read correctly
  in light and dark.

Discover the real simulators and, for Android, the real emulators before claiming a device
was tested, and record any missing runtime as a verification gap. Commit with plain messages,
no em-dash and no AI attribution, and branch rather than committing to the default branch
without approval. This is a private app: do not publish, do not change signing identities,
and do not upload to any store without an explicit instruction.
