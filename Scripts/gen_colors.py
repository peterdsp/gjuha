#!/usr/bin/env python3
"""Generate the Gjuha Named Color asset catalog, and measure its contrast.

Four things this script fixes relative to the version it replaces:

1. **It writes to the catalog the app actually loads.** The old script wrote into
   `Assets.xcassets`, but every colorset lives in `Palette.xcassets`, so running
   it produced a second, unused set of colors and silently changed nothing.

2. **Every token carries four appearances, not two.** Light and dark are not
   enough: Apple's Color guidance asks for an increased-contrast variant of a
   custom color as well, and without one the Increase Contrast accessibility
   setting had no effect anywhere in this app. Each colorset now ships
   light / dark / light+high / dark+high.

3. **Fill and on-surface text are separate roles.** Gold, flame orange, green
   and red read well as a *fill* behind white and badly as *text* on a white
   surface: gold text on `Surface` measured 1.76:1. The `*Strong` tokens are the
   on-surface (text and icon) member of each pair; the unsuffixed token is the
   fill. A fill that carries white text was deepened until white actually clears
   4.5:1 on it; `Warning` and `XP` stay bright and take the dark `OnWarning`
   foreground instead, because deepening gold far enough for white turns it
   brown.

4. **Overlay tints are tokens, not `Color.white.opacity(…)`.** A white overlay
   is invisible on a white surface, so in light appearance every hardcoded one
   disappeared: card edges, progress tracks, chip fills and the borders of
   tappable answer options all had no visible boundary. `Hairline`, `GlassTint`,
   `Track`, `ChipFill` and `ControlFill` invert with the appearance instead.

Ratios below are computed here, and `GjuhaContrastTests` asserts the same floors
against the colors the app resolves at runtime, so the catalog and the claim
cannot drift apart.

Run:
    python3 Scripts/gen_colors.py
"""
from __future__ import annotations

import json
import os
import sys

ASSETS_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "Gjuha", "Resources", "Palette.xcassets"
)

# name: (light, dark, light_high_contrast, dark_high_contrast)
# Each value is (r, g, b) or (r, g, b, alpha), all 0-1 sRGB.
COLORS: dict[str, tuple] = {
    # --- Brand ------------------------------------------------------------
    # `Accent` is the fill (buttons, gradients, lesson nodes) and carries
    # `OnAccent` white. `AccentStrong` is the on-surface text and icon member.
    # The two move in opposite directions in dark appearance: a fill under white
    # text has to stay deep, while text on a dark surface has to go light.
    "Accent":           ((0.839, 0.192, 0.165), (0.839, 0.196, 0.169),
                         (0.722, 0.133, 0.110), (0.722, 0.133, 0.110)),
    "AccentStrong":     ((0.722, 0.133, 0.110), (1.000, 0.455, 0.420),
                         (0.588, 0.078, 0.063), (1.000, 0.588, 0.561)),
    "AccentSubtle":     ((0.984, 0.910, 0.906), (0.200, 0.071, 0.063),
                         (0.973, 0.855, 0.847), (0.251, 0.086, 0.075)),

    # --- Background hierarchy --------------------------------------------
    "Background":       ((0.961, 0.957, 0.953), (0.063, 0.063, 0.071),
                         (1.000, 1.000, 1.000), (0.000, 0.000, 0.000)),
    "Surface":          ((1.000, 1.000, 1.000), (0.118, 0.118, 0.133),
                         (1.000, 1.000, 1.000), (0.149, 0.149, 0.165)),
    "SurfaceSecondary": ((0.933, 0.929, 0.922), (0.169, 0.169, 0.188),
                         (0.898, 0.894, 0.886), (0.212, 0.212, 0.235)),

    # --- Text -------------------------------------------------------------
    # Tertiary was 0.620 light / 0.380 dark, which measured 2.70:1 and 2.99:1
    # against its own background: below the 4.5:1 text floor in both
    # appearances, on real captions ("Complete all lessons above to unlock").
    "TextPrimary":      ((0.102, 0.102, 0.118), (0.953, 0.953, 0.961),
                         (0.000, 0.000, 0.000), (1.000, 1.000, 1.000)),
    "TextSecondary":    ((0.400, 0.400, 0.420), (0.580, 0.580, 0.600),
                         (0.251, 0.251, 0.271), (0.722, 0.722, 0.741)),
    "TextTertiary":     ((0.431, 0.431, 0.451), (0.561, 0.561, 0.580),
                         (0.329, 0.329, 0.349), (0.702, 0.702, 0.722)),

    # --- State: fill (carries OnAccent), then the on-surface member -------
    "Success":          ((0.086, 0.510, 0.290), (0.086, 0.510, 0.290),
                         (0.059, 0.420, 0.239), (0.059, 0.420, 0.239)),
    "SuccessStrong":    ((0.055, 0.455, 0.251), (0.400, 0.871, 0.600),
                         (0.027, 0.361, 0.196), (0.549, 0.922, 0.702)),
    "Error":            ((0.820, 0.137, 0.110), (0.820, 0.137, 0.110),
                         (0.690, 0.094, 0.075), (0.690, 0.094, 0.075)),
    "ErrorStrong":      ((0.722, 0.102, 0.078), (1.000, 0.486, 0.451),
                         (0.588, 0.055, 0.039), (1.000, 0.612, 0.580)),

    # `Warning` and `XP` keep their bright amber and gold in every appearance
    # and take the dark `OnWarning` foreground. Deepening either far enough to
    # carry white turns it brown and costs the reward signal its meaning.
    "Warning":          ((0.988, 0.718, 0.145), (0.988, 0.741, 0.165),
                         (0.941, 0.667, 0.078), (1.000, 0.796, 0.247)),
    "WarningStrong":    ((0.561, 0.376, 0.000), (1.000, 0.816, 0.400),
                         (0.451, 0.298, 0.000), (1.000, 0.878, 0.561)),
    "XP":               ((0.988, 0.718, 0.145), (1.000, 0.780, 0.196),
                         (0.941, 0.667, 0.078), (1.000, 0.831, 0.286)),
    "XPStrong":         ((0.573, 0.388, 0.000), (1.000, 0.839, 0.400),
                         (0.459, 0.306, 0.000), (1.000, 0.894, 0.561)),

    # --- Gamification -----------------------------------------------------
    "Streak":           ((0.769, 0.286, 0.020), (0.769, 0.286, 0.020),
                         (0.651, 0.235, 0.012), (0.651, 0.235, 0.012)),
    "StreakStrong":     ((0.667, 0.263, 0.000), (1.000, 0.651, 0.329),
                         (0.541, 0.208, 0.000), (1.000, 0.741, 0.490)),

    # --- Separators, edges and overlay fills ------------------------------
    "Border":           ((0.867, 0.863, 0.855), (0.220, 0.220, 0.240),
                         (0.651, 0.647, 0.639), (0.420, 0.420, 0.447)),
    "Hairline":         ((0.102, 0.102, 0.118, 0.140), (1.000, 1.000, 1.000, 0.220),
                         (0.102, 0.102, 0.118, 0.400), (1.000, 1.000, 1.000, 0.480)),
    "GlassTint":        ((1.000, 1.000, 1.000, 0.560), (1.000, 1.000, 1.000, 0.060),
                         (1.000, 1.000, 1.000, 0.820), (0.149, 0.149, 0.165, 0.760)),
    "Track":            ((0.102, 0.102, 0.118, 0.120), (1.000, 1.000, 1.000, 0.160),
                         (0.102, 0.102, 0.118, 0.320), (1.000, 1.000, 1.000, 0.380)),
    "ChipFill":         ((0.102, 0.102, 0.118, 0.060), (1.000, 1.000, 1.000, 0.120),
                         (0.102, 0.102, 0.118, 0.140), (1.000, 1.000, 1.000, 0.220)),
    "ControlFill":      ((0.102, 0.102, 0.118, 0.050), (1.000, 1.000, 1.000, 0.100),
                         (1.000, 1.000, 1.000, 1.000), (0.149, 0.149, 0.165, 1.000)),

    # --- Foreground on a fill ---------------------------------------------
    # These exist as tokens so a view drawing on a brand fill says so, instead
    # of reaching for `.white` and leaving the next reader to work out whether
    # it was deliberate or an accident that happens to look right in dark mode.
    "OnAccent":         ((1.000, 1.000, 1.000), (1.000, 1.000, 1.000),
                         (1.000, 1.000, 1.000), (1.000, 1.000, 1.000)),
    "OnWarning":        ((0.102, 0.102, 0.118), (0.102, 0.102, 0.118),
                         (0.000, 0.000, 0.000), (0.000, 0.000, 0.000)),
}

APPEARANCES = [
    (None, None),
    ("dark", None),
    (None, "high"),
    ("dark", "high"),
]

APPEARANCE_NAMES = ["light", "dark", "light+HC", "dark+HC"]

# Pairs the app actually renders. Index 0/2 are light appearances, 1/3 dark.
# Everything here is text or an icon that must stay legible, so all of it is
# held to the 4.5:1 normal-text floor rather than the 3:1 large-text relaxation.
TEXT_PAIRS = [
    ("TextPrimary", "Surface"),
    ("TextSecondary", "Surface"),
    ("TextTertiary", "Surface"),
    ("TextPrimary", "Background"),
    ("TextSecondary", "Background"),
    ("TextTertiary", "Background"),
    ("TextPrimary", "SurfaceSecondary"),
    ("TextSecondary", "SurfaceSecondary"),
    ("AccentStrong", "Surface"),
    ("AccentStrong", "Background"),
    ("SuccessStrong", "Surface"),
    ("ErrorStrong", "Surface"),
    ("WarningStrong", "Surface"),
    ("StreakStrong", "Surface"),
    ("XPStrong", "Surface"),
    ("StreakStrong", "Background"),
    ("XPStrong", "Background"),
    # Foreground on a brand or state fill.
    ("OnAccent", "Accent"),
    ("OnAccent", "Streak"),
    ("OnAccent", "Success"),
    ("OnAccent", "Error"),
    ("OnWarning", "Warning"),
    ("OnWarning", "XP"),
]

TEXT_FLOOR = 4.5


def make_color(value: tuple) -> dict:
    r, g, b = value[0], value[1], value[2]
    alpha = value[3] if len(value) > 3 else 1.0
    return {
        "color-space": "srgb",
        "components": {
            "alpha": f"{alpha:.3f}",
            "red": f"{r:.3f}",
            "green": f"{g:.3f}",
            "blue": f"{b:.3f}",
        },
    }


def entry(value: tuple, luminosity: str | None, contrast: str | None) -> dict:
    appearances = []
    if luminosity:
        appearances.append({"appearance": "luminosity", "value": luminosity})
    if contrast:
        appearances.append({"appearance": "contrast", "value": contrast})
    result: dict = {"color": make_color(value), "idiom": "universal"}
    if appearances:
        result["appearances"] = appearances
    return result


# --- Contrast measurement -------------------------------------------------


def _linear(channel: float) -> float:
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def relative_luminance(value: tuple) -> float:
    r, g, b = (_linear(c) for c in value[:3])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(fg: tuple, bg: tuple) -> float:
    """WCAG 2.1 contrast ratio. Both colors must be opaque."""
    a, b = relative_luminance(fg), relative_luminance(bg)
    lighter, darker = max(a, b), min(a, b)
    return (lighter + 0.05) / (darker + 0.05)


def report_contrast() -> int:
    """Print every measured ratio. Returns the count below the text floor."""
    print("\nMeasured contrast (WCAG 2.1), foreground token vs the surface behind it:")
    print(f"{'pair':<34} " + "".join(f"{name:>10}" for name in APPEARANCE_NAMES))
    failures = 0
    for fg_name, bg_name in TEXT_PAIRS:
        cells = []
        for index in range(4):
            ratio = contrast_ratio(COLORS[fg_name][index], COLORS[bg_name][index])
            flag = "" if ratio >= TEXT_FLOOR else "!"
            if flag:
                failures += 1
            cells.append(f"{ratio:>9.2f}{flag}")
        print(f"{fg_name + ' on ' + bg_name:<34} " + "".join(cells))
    return failures


def main() -> int:
    if not os.path.isdir(ASSETS_DIR):
        print(f"asset catalog not found: {ASSETS_DIR}", file=sys.stderr)
        return 1

    for name, values in COLORS.items():
        if len(values) != 4:
            print(f"{name} must define all four appearances", file=sys.stderr)
            return 1
        colorset_dir = os.path.join(ASSETS_DIR, f"{name}.colorset")
        os.makedirs(colorset_dir, exist_ok=True)
        contents = {
            "colors": [
                entry(value, luminosity, contrast)
                for value, (luminosity, contrast) in zip(values, APPEARANCES)
            ],
            "info": {"author": "xcode", "version": 1},
        }
        with open(os.path.join(colorset_dir, "Contents.json"), "w") as handle:
            json.dump(contents, handle, indent=2)
            handle.write("\n")

    print(f"{len(COLORS)} colorsets written to {os.path.normpath(ASSETS_DIR)}")

    failures = report_contrast()
    if failures:
        print(
            f"\n{failures} pair(s) marked ! are below {TEXT_FLOOR}:1 and are not "
            "safe for text.",
            file=sys.stderr,
        )
        return 1
    print(f"\nEvery measured pair is at or above {TEXT_FLOOR}:1.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
