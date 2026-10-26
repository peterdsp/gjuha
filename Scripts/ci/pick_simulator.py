#!/usr/bin/env python3
"""Print the udid of a usable iOS simulator.

CI runner images change their simulator line-up between releases, so hardcoding
a device name ("iPhone 15", "iPhone 17") makes the workflow break on an image
bump for a reason that has nothing to do with the app. This resolves a concrete
udid at run time instead.

Preference order: a plain iPhone first, because it is the device the app is
primarily designed for and gives the most representative run; then anything else
available. Within a tier, the name sorts so the choice is deterministic rather
than dependent on dictionary order.

Reads `xcrun simctl list devices available --json` on stdin, prints the udid on
stdout, and a human readable note on stderr.

    xcrun simctl list devices available --json | python3 Scripts/ci/pick_simulator.py
"""
from __future__ import annotations

import json
import sys


def main() -> int:
    try:
        devices = json.load(sys.stdin)["devices"]
    except (json.JSONDecodeError, KeyError) as exc:
        print(f"could not read simctl output: {exc}", file=sys.stderr)
        return 1

    best: tuple[tuple[int, str], str, str, str] | None = None
    for runtime, entries in devices.items():
        if "iOS" not in runtime:
            continue
        for device in entries:
            if not device.get("isAvailable"):
                continue
            name = device["name"]
            score = (0 if name.startswith("iPhone") else 1, name)
            if best is None or score < best[0]:
                best = (score, device["udid"], runtime, name)

    if best is None:
        print("no available iOS simulator on this runner", file=sys.stderr)
        return 1

    _, udid, runtime, name = best
    print(f"selected {name} on {runtime} ({udid})", file=sys.stderr)
    print(udid)
    return 0


if __name__ == "__main__":
    sys.exit(main())
