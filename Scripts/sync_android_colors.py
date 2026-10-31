#!/usr/bin/env python3
"""Generate the Compose palette from the iOS colour catalog.

Colour in this app has one source: Scripts/gen_colors.py writes
Palette.xcassets and measures the contrast of every pair the app renders.
The Android colours were typed in by hand from those values, which is a second
source of truth waiting to drift, and nothing would have reported it.

They are read out of the generated catalog now, so changing a hue in
gen_colors.py and re-running both scripts reaches Compose as well.

    python3 Scripts/sync_android_colors.py          # write
    python3 Scripts/sync_android_colors.py --check  # fail if out of date

Only the light and dark appearances are carried. Compose has no equivalent of
the increased-contrast appearance, so those two entries stay an iOS-only
refinement rather than being flattened into something Android cannot express.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Gjuha/Resources/Palette.xcassets"
THEME = ROOT / "android/app/src/main/kotlin/com/gjuha/app/Theme.kt"

# The tokens Compose actually draws with. Deliberately a subset: a token the
# Android app never reads would be dead weight that still has to be kept true.
# Catalog token -> the Kotlin name the app already uses. They differ only for
# XP, where Kotlin casing wants Xp and the catalog wants XP; renaming the call
# sites to match the catalog would be a wider diff for no gain.
TOKENS = {
    "Accent": "Accent",
    "AccentStrong": "AccentStrong",
    "Streak": "Streak",
    "StreakStrong": "StreakStrong",
    "XP": "Xp",
    "XPStrong": "XpStrong",
    "Success": "Success",
    "SuccessStrong": "SuccessStrong",
    "Error": "Error",
    "Background": "Background",
    "Surface": "Surface",
    "TextPrimary": "TextPrimary",
    "TextSecondary": "TextSecondary",
    "OnAccent": "OnAccent",
    "OnWarning": "OnWarning",
}

HEADER = """object GjuhaColors {
    // Generated from Gjuha/Resources/Palette.xcassets by
    // Scripts/sync_android_colors.py. Do not hand edit.
    //
    // Colour has one source, the iOS catalog, because that is where the
    // contrast of every rendered pair is measured. These were previously typed
    // in by hand, which is a second source waiting to drift with nothing to
    // report it.
    //
    // The role split carries over: a fill carries OnAccent or OnWarning, and a
    // *Strong member is for text or an icon drawn on a surface. Gold as text on
    // a white surface measures 1.76:1, which is why XPStrong exists at all.
"""


def argb(token, dark):
    """The light or dark appearance of a token, as Compose's 0xAARRGGBB."""
    path = CATALOG / f"{token}.colorset" / "Contents.json"
    if not path.exists():
        sys.exit(f"No colorset for {token}. Run Scripts/gen_colors.py first.")
    for entry in json.loads(path.read_text())["colors"]:
        appearances = entry.get("appearances") or []
        if any(a.get("appearance") == "contrast" for a in appearances):
            continue
        is_dark = any(a.get("value") == "dark" for a in appearances)
        if is_dark != dark:
            continue
        parts = entry["color"]["components"]
        red, green, blue = (float(parts[k]) for k in ("red", "green", "blue"))
        alpha = float(parts.get("alpha", 1))
        return "0x%02X%02X%02X%02X" % (
            round(alpha * 255), round(red * 255), round(green * 255), round(blue * 255)
        )
    sys.exit(f"{token} has no {'dark' if dark else 'light'} appearance.")


def render():
    lines = [HEADER]
    for token, name in TOKENS.items():
        lines.append(f"    val {name} = Color({argb(token, False)})")
        lines.append(f"    val {name}Dark = Color({argb(token, True)})")
    lines.append("}")
    return "\n".join(lines)


def main():
    source = THEME.read_text()
    match = re.search(r"object GjuhaColors \{.*?\n\}", source, re.S)
    if not match:
        sys.exit("Could not find object GjuhaColors in Theme.kt")

    wanted = source[:match.start()] + render() + source[match.end():]

    if "--check" in sys.argv:
        if source != wanted:
            print("Theme.kt does not match the colour catalog. Re-run this script.")
            return 1
        print(f"Compose palette matches the iOS catalog ({len(TOKENS)} tokens).")
        return 0

    THEME.write_text(wanted)
    print(f"Wrote {len(TOKENS)} tokens into {THEME.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
