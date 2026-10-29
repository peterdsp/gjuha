# Design System

How to pick a colour, a spacing step and a button style in Gjuha, and why the
tokens are shaped the way they are. The project rule is that no view hardcodes a
colour or a font size; this is the reference that makes that rule followable.

Source of truth:

- Colours: `Scripts/gen_colors.py` generates `Gjuha/Resources/Palette.xcassets`,
  surfaced by `Gjuha/Core/DesignSystem/Colors/GjuhaColors.swift`.
- Surfaces: `Gjuha/Core/DesignSystem/Surfaces/GjuhaSurface.swift`.
- Mascot: `Gjuha/Core/DesignSystem/Mascot/MascotView.swift`.
- Spacing and radii: `Gjuha/Core/DesignSystem/Spacing/GjuhaSpacing.swift`.
- Type scale: `Gjuha/Core/DesignSystem/Typography/GjuhaFonts.swift`.
- Button styles: `Gjuha/Core/DesignSystem/Buttons/GjuhaButtonStyles.swift`.

---

## Colour

### Four appearances, not two

Every token ships light, dark, light+increased-contrast and
dark+increased-contrast. The increased-contrast pair is not optional polish: with
only light and dark, the system's **Increase Contrast** accessibility setting had
no effect anywhere in this app, because a Named Color with no `contrast: high`
entry resolves to its ordinary variant.

### Fill and on-surface text are different roles

This is the distinction to get right when picking a token.

| Role | Tokens | Used for |
|---|---|---|
| **Fill** | `accent`, `success`, `warning`, `error`, `streak`, `xp` | A shape that sits *behind* a foreground: a button, a banner, a lesson node, a badge circle, a gradient. |
| **On-surface** | `accentStrong`, `successStrong`, `warningStrong`, `errorStrong`, `streakStrong`, `xpStrong` | Text or an icon drawn *on* `surface` / `background`. |
| **On-fill** | `onAccent`, `onWarning` | The foreground that goes on a fill. |

The reason the pairs exist is measured, not aesthetic. Gold reads well as a fill
behind white and measures **1.76:1** as text on a white surface, which is not
legible by any standard. The app used to do exactly that: the XP star and its
number on Home, the stat tiles in Profile, and the widget's symbols were all
tinted with fills.

Picking the on-fill token:

- `onAccent` (white) goes on `accent`, `streak`, `success` and `error`. Those four
  fills were deepened until white clears 4.5:1 on them.
- `onWarning` (near-black) goes on `warning` and `xp`. Deepening gold or amber far
  enough to carry white turns it brown and costs the reward signal its meaning, so
  those two stay bright and take a dark foreground instead.

### Overlay tints

`hairline`, `glassTint`, `track`, `chipFill` and `controlFill` replaced hardcoded
`Color.white.opacity(…)` overlays. A white overlay on a white surface is
invisible, and `Surface` in light appearance is `#FFFFFF`, so in light mode every
one of those overlays disappeared: glass cards had no edge, progress tracks were
blank, chips had no background, and the border that marked an answer option as
tappable was not drawn. These tokens invert with the appearance.

| Token | Use |
|---|---|
| `hairline` | The edge of a card or a tappable surface. |
| `glassTint` | The tint laid over a material inside a glass card. |
| `track` | The unfilled part of a progress bar, ring or meter. |
| `chipFill` | Background of a small capsule chip. |
| `controlFill` | Background of an unselected, tappable option row. |

### The contrast floor is enforced twice

`Scripts/gen_colors.py` computes the WCAG 2.1 ratio for every pair it ships and
**exits non-zero** rather than writing a set that falls below 4.5:1. That alone
would not be worth much, because the asset catalog can be edited in Xcode without
anyone running the script, so `GjuhaContrastTests` measures the same pairs against
the colours the app resolves at runtime, across all four appearances.

The two agreeing is the only reason either claim means anything. They do agree:
`textPrimary` on `surface` is 17.35:1 from the script and 17.346 from the running
app.

Everything checked is held to the 4.5:1 normal-text floor rather than the 3:1
large-text relaxation, because the relaxation depends on a rendered point size
that a token does not know about.

```sh
python3 Scripts/gen_colors.py   # regenerates and prints the full table
```

---

## Surfaces and the two layers

Apple's materials model has exactly two layers, and which one a view belongs to
decides what it may be made of.

| Layer | What is in it | What it is made of |
|---|---|---|
| **Content** | Cards, stat tiles, rows, chips, page backgrounds | Opaque colours or **standard materials**. Never Liquid Glass. |
| **Functional** | Tab bar, navigation bar, sheets, a bar pinned over scrolling content | Liquid Glass, which the system applies to its own components for free |

Everything this app draws in a card is content. The modifier that draws it was
called `gjuhaLiquidGlassCard`, which told every reader the opposite of the truth,
and the app's real functional layer is now the native tab bar and navigation bar,
where the system supplies the material.

Use `.gjuhaCardSurface(cornerRadius:prominence:)`:

| Prominence | When | Draws |
|---|---|---|
| `.nested` | Inside another surface: a stat tile in a card, a chip in a row | `chipFill`, no shadow |
| `.standard` | A content card on the page | `.regularMaterial`, shadow |
| `.prominent` | The one surface a screen leads with | `.regularMaterial`, shadow |

`.nested` is not a cosmetic level. A material inside a material is the stacked
glass case that blurs the hierarchy the material exists to create, and it also
stacks two shadows that describe a depth nothing physical has.

The material is **regular**, not ultra-thin. Every one of these surfaces is full
of text, and Apple's Materials guidance is that "thicker materials, which are more
opaque, can provide better contrast for text and other elements with fine
features". The previous ultra-thin material was the thinnest option available,
under the text of a question a learner has to read to answer it.

### Accessibility fallbacks

`GjuhaSurfaceStyle.resolve(prominence:reduceTransparency:increaseContrast:)` is a
pure function, split out so it can be asserted. A `ViewModifier` cannot be
inspected from a unit test, so without the split the Reduce Transparency answer
would be a comment with nothing behind it, which is the state the app was in:
roughly thirty surfaces were built on a material and not one of them read the
setting.

- **Reduce Transparency** removes every material and tint. A nested surface goes
  to `surfaceSecondary` rather than `surface`, so a stat tile does not vanish into
  the card holding it.
- **Increase Contrast** widens the border as well as darkening it, because the
  `hairline` token already carries a stronger increased-contrast value and width
  is what makes a boundary unmistakable.
- **Reduce Motion** stops the ambient background's drift, and Reduce Transparency
  flattens it to a single colour: its blurred shapes are translucent forms, and
  keeping them while claiming to have reduced transparency would be a half-answer.

For a text-bearing interactive control that is not a card, use
`GjuhaSurfaceStyle.restingControlFill(reduceTransparency:)`. For a bar floating
over scrolling content, use `floatingBarFill(reduceTransparency:)`: that one
really is the functional layer, so a material belongs there.

`GjuhaSurfaceTests` asserts the whole table, including that nothing translucent
survives Reduce Transparency at any prominence with Increase Contrast either on or
off.

---

## Adapting to width

Decide layout from the **horizontal size class**, never from device or
orientation: Apple's Layout guidance is to "determine layout based on size
classes, not device type or orientation", and it is also what gives iPhone Duo its
layout for free, where the outer display is compact and the inner one regular.

`Profile` is the worked example. Six stat tiles, twelve badges, a goal picker and
two settings blocks are independent of each other, so at a regular width they
split into two columns and the readable-width cap widens from 620 to 1040. Two
columns rather than three on purpose: iPhone Duo's fold divides the inner display,
and that guidance asks for an even number of columns "so content divides cleanly".

`Home` splits the same way, for a different reason. The lesson map is one
vertical flow and reads correctly centred, so it is not split; what was wrong at a
regular width was everything around it. The unit card, the review prompt and the
culture card were stacked above and below the map, so reaching the lessons meant
scrolling past a screen of context and finding the culture card meant scrolling
the whole map again. They move into a leading rail and the map keeps its column.

`gjuhaReadableWidth(_:)` caps a single column of prose at a comfortable measure.
Pass a wider value when the content is a grid of cards rather than text, because
the measure argument does not apply to it.

**Test both widths.** The app ships for iPhone and iPad, and the UI suite runs on
both. That is not ceremony: the first iPad run failed four of eight tests, because
iPadOS publishes each tab button twice and the tests' element query was ambiguous.
A suite that only ever ran on one family would have reported green.

---

## Imagery

The mascot is the app's one piece of character art, and it animates through
`CGAnimateImageDataWithBlock` in `MascotView.swift`.

It used to animate through a `WKWebView`: the 1.2 MB GIF was base64-encoded into
an HTML document and handed to a web view to play, once per mascot on screen.
That started an out-of-process web renderer per instance, inflated the asset by a
third on every load, and linked WebKit into an app with no web content. Image I/O
decodes frames on demand and honours the GIF's own delays, so memory stays at a
frame or two rather than the 25 MB that holding all 37 frames would cost.

Two rules for any animated art added later:

- **Reduce Motion gets the still image**, not a slower loop. Gating only the
  fallback, which an earlier version of this view did, leaves the animation
  running for exactly the people who asked for less of it.
- **The art is `accessibilityHidden`.** The mascot repeats what the text beside it
  already says, so announcing it adds a stop to the VoiceOver path and no
  information.

---

## Spacing

The 4pt grid, as named steps: `hairline` 4, `tight` 8, `snug` 12, `regular` 16,
`loose` 24, `section` 32, `hero` 48. Reach for them as `.gjuha.regular` rather
than `16`.

Radii live in `GjuhaSpacing.Radius`: `small` 10, `medium` 14, `large` 18,
`prominent` 22. Use the same constant for a shape and the stroke drawn over it,
or a sliver of stroke shows outside the fill.

`GjuhaSpacing.minimumHitTarget` is 44pt, and `.gjuhaMinimumHitTarget()` applies it
to a control whose visible shape is smaller.

`GjuhaSpacingTests` asserts every step stays on the grid and that the steps remain
distinct and ordered.

---

## Buttons

Three styles, and no view should rebuild one by hand.

| Style | Use |
|---|---|
| `.gjuhaPrimary` | The screen's main action. Full-width accent gradient carrying `onAccent`. |
| `.gjuhaSecondary` | A second way out that should not compete with the primary. |
| `.gjuhaCard` | A whole card or node that acts as a button. Adds press feedback and nothing else. |

Two things these fixed. The primary action was a copy-pasted gradient in four
places, all of them `.buttonStyle(.plain)`, which means none of them reacted to
touch at all: on a screen where the same button is pressed dozens of times a
session, that reads as an unresponsive tap. And the gradient's second stop was
`streak.opacity(0.94)`; lightening a fill under white text drops it below the
4.5:1 the palette was tuned for, so the stop is now the opaque token.

A pressed primary button *darkens*. Brightening would push it under the floor.

---

## Motion policy

Every repeating or decorative animation checks
`@Environment(\.accessibilityReduceMotion)` and collapses to
`.linear(duration: 0.01)`. That includes the ambient background drift, the mascot
loop (which falls through to a still image rather than a slower loop), the header
metric breathing, the confetti burst and the goal-ring fill.

---

## Type

`Font.gjuha.*` tokens are built through `UIFontMetrics`, so they scale with the
user's preferred text size instead of staying pinned at their design size. A view
that lays several labels in a row should branch on
`@Environment(\.dynamicTypeSize)`'s `isAccessibilitySize` and stack them instead
of truncating; the Home header and the unit metric chips both do this.

---

## Adding a token

1. Add it to `COLORS` in `Scripts/gen_colors.py` with all four appearances.
2. If it is a foreground, add its pair to `TEXT_PAIRS` so it gets measured.
3. Run `python3 Scripts/gen_colors.py`. It fails if the pair is below the floor.
4. Expose it on `GjuhaColors`, documenting which role it is.
5. Add it to the matching list in `GjuhaContrastTests`.
6. If the widget needs it, add it to `GjuhaWidgets/WidgetPalette.swift`. The
   values are not duplicated: both targets include the same catalog.
