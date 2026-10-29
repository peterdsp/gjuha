#!/usr/bin/env python3
"""Restore readable names to screenshots exported from an .xcresult bundle.

`xcresulttool export attachments` writes every attachment under an opaque UUID
filename and records the name the test gave it in `manifest.json`. Without this
step the output is six indistinguishable PNGs, which is useless for picking the
order they go into App Store Connect.

    python3 Scripts/rename_screenshots.py <dir-containing-manifest.json>
"""
from __future__ import annotations

import json
import pathlib
import re
import shutil
import sys

# XCTest appends "_<index>_<uuid>.png" to the name passed to XCTAttachment.
SUFFIX = re.compile(r"_\d+_[0-9A-F-]{36}\.png$", re.IGNORECASE)


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2

    out = pathlib.Path(sys.argv[1])
    manifest = out / "manifest.json"
    if not manifest.exists():
        print(f"no manifest.json in {out}", file=sys.stderr)
        return 1

    renamed = 0
    for group in json.loads(manifest.read_text()):
        for attachment in group.get("attachments", []):
            source = out / attachment.get("exportedFileName", "")
            name = SUFFIX.sub("", attachment.get("suggestedHumanReadableName", ""))
            if source.exists() and name:
                shutil.move(str(source), str(out / f"{name}.png"))
                renamed += 1

    manifest.unlink()
    print(f"renamed {renamed} screenshot(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
