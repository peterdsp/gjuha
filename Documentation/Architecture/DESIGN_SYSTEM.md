# Design System

How to pick a colour, a spacing step and a button style in Gjuha, and why the
tokens are shaped the way they are. The project rule is that no view hardcodes a
colour or a font size; this is the reference that makes that rule followable.

Source of truth:

- Colours: `Scripts/gen_colors.py` generates `Gjuha/Resources/Palette.xcassets`,
  surfaced by `Gjuha/Core/DesignSystem/Colors/GjuhaColors.swift`.
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

## Motion

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
