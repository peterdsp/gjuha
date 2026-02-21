#!/usr/bin/env python3
"""Generate Named Color asset catalog entries for the Gjuha design system."""
import json, os

ASSETS_DIR = os.path.join(os.path.dirname(__file__), "..", "Gjuha", "Resources", "Assets.xcassets")

COLORS = {
    # name: (light_rgb, dark_rgb)
    "Accent":          ((0.867, 0.216, 0.188), (0.922, 0.310, 0.275)),
    "AccentSubtle":    ((0.984, 0.910, 0.906), (0.200, 0.071, 0.063)),
    "Background":      ((0.961, 0.957, 0.953), (0.063, 0.063, 0.071)),
    "Surface":         ((1.000, 1.000, 1.000), (0.118, 0.118, 0.133)),
    "SurfaceSecondary":((0.933, 0.929, 0.922), (0.169, 0.169, 0.188)),
    "TextPrimary":     ((0.102, 0.102, 0.118), (0.953, 0.953, 0.961)),
    "TextSecondary":   ((0.400, 0.400, 0.420), (0.580, 0.580, 0.600)),
    "TextTertiary":    ((0.620, 0.620, 0.640), (0.380, 0.380, 0.400)),
    "Success":         ((0.173, 0.706, 0.424), (0.235, 0.796, 0.502)),
    "Warning":         ((0.988, 0.718, 0.145), (0.988, 0.780, 0.200)),
    "Error":           ((0.918, 0.231, 0.196), (0.957, 0.337, 0.302)),
    "Streak":          ((1.000, 0.478, 0.118), (1.000, 0.549, 0.200)),
    "XP":              ((0.988, 0.718, 0.145), (1.000, 0.800, 0.200)),
    "Border":          ((0.867, 0.863, 0.855), (0.220, 0.220, 0.240)),
}

def make_color(r, g, b):
    return {
        "color-space": "srgb",
        "components": {
            "alpha": "1.000",
            "red":   f"{r:.3f}",
            "green": f"{g:.3f}",
            "blue":  f"{b:.3f}",
        }
    }

for name, (light, dark) in COLORS.items():
    colorset_dir = os.path.join(ASSETS_DIR, f"{name}.colorset")
    os.makedirs(colorset_dir, exist_ok=True)
    contents = {
        "colors": [
            {
                "color": make_color(*light),
                "idiom": "universal"
            },
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "color": make_color(*dark),
                "idiom": "universal"
            }
        ],
        "info": {"author": "xcode", "version": 1}
    }
    path = os.path.join(colorset_dir, "Contents.json")
    with open(path, "w") as f:
        json.dump(contents, f, indent=2)
    print(f"  ✓ {name}")

print(f"\nGenerated {len(COLORS)} colorsets in {ASSETS_DIR}")
