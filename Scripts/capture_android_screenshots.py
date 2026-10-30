#!/usr/bin/env python3
"""Captures Play Store screenshots by playing the app, not by seeding it.

Everything shown is state the app reached through its own interface: the XP,
the accuracy and the badge on the completion screen were earned by answering
the questions. A screenshot of a figure nobody earned is a claim about the
product that is not true.

    bash -c 'python3 Scripts/capture_android_screenshots.py'
    python3 Scripts/capture_android_screenshots.py --serial emulator-5556

Output lands in AndroidScreenshots/, which is gitignored: the images are build
output, reproducible from this script.

Play requires each phone screenshot to be at least 320px and at most 3840px on
its longest side, with a ratio no wider than 2:1. The emulator used here is
1080x2400, which satisfies that.
"""
import argparse
import pathlib
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from android.play import ACTIVITY, PACKAGE, Device, Lexicon, find, play_lesson

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "AndroidScreenshots"


class NeverAppeared(RuntimeError):
    """A screen the capture expected never arrived."""


def wait_for(device, text, timeout=40, contains=False):
    """Blocks until a screen showing `text` is up, then returns its elements.

    Every wait here is on a thing the screen must show, never on a duration.
    A fixed sleep captured the launch splash as the onboarding screen, because
    a cold start after `pm clear` has no profile and takes longer than the
    sleep allowed. A capture that quietly photographs the wrong screen is worse
    than one that fails.
    """
    deadline = time.time() + timeout
    while time.time() < deadline:
        elements = device.screen()
        for element in elements:
            if element["text"] == text or (contains and text in element["text"]):
                return elements
        time.sleep(1.0)
    raise NeverAppeared(f"{text!r} never appeared within {timeout}s")


def reset(device):
    """Back to first launch, so onboarding is captured as a learner sees it."""
    device.sh("shell", "am", "force-stop", PACKAGE)
    device.sh("shell", "pm", "clear", PACKAGE)
    device.sh("shell", "am", "start", "-n", ACTIVITY)
    # A cold start after a clear is slow, so this waits for the goal picker
    # itself rather than guessing how long it takes.
    wait_for(device, "Start learning")


def tap_text(device, text, settle=2.5, contains=False):
    for element in device.screen():
        if element["text"] == text or (contains and text in element["text"]):
            device.tap(element["cx"], element["cy"], settle=settle)
            return True
    raise NeverAppeared(f"nothing to tap matching {text!r}")


def shot(device, name, index):
    path = OUT / f"{index:02d}-{name}.png"
    size = device.capture(path)
    print(f"  {path.name}  {size // 1024} KB")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--serial", default="emulator-5554")
    args = parser.parse_args()

    device = Device(args.serial)
    if "device" not in device.sh("get-state"):
        print(f"No device at {args.serial}. Start the emulator first.")
        return 1

    OUT.mkdir(exist_ok=True)
    lexicon = Lexicon()

    print("Resetting to first launch")
    reset(device)
    shot(device, "Onboarding-daily-goal", 1)

    # Regular, so the daily target matches the iOS screenshots at 120 XP.
    tap_text(device, "10 min/day · 120 XP", contains=True)
    tap_text(device, "Start learning", settle=4)
    wait_for(device, "Greetings & introducing yourself")
    shot(device, "Learn-lesson-map", 2)

    print("Opening the first lesson")
    tap_text(device, "Greetings & introducing yourself", settle=6)
    wait_for(device, "Exit lesson")
    shot(device, "Lesson-question", 3)

    print("Playing it")
    if not play_lesson(device, lexicon, verbose=True):
        print("The lesson did not complete; not capturing an unearned result.")
        return 1
    wait_for(device, "Lesson complete!")
    time.sleep(1.0)
    shot(device, "Lesson-complete-earned", 4)

    tap_text(device, "Continue", settle=4)
    wait_for(device, "Greetings & introducing yourself")

    tap_text(device, "Words", settle=3)
    wait_for(device, "Search words...")
    shot(device, "Words-met-so-far", 5)

    tap_text(device, "Grammar", settle=3)
    wait_for(device, "Noun Definiteness")
    tap_text(device, "Noun Definiteness", settle=2)
    wait_for(device, "Examples")
    shot(device, "Grammar-definiteness", 6)

    tap_text(device, "Profile", settle=3)
    wait_for(device, "Mastered")
    shot(device, "Profile-honest-progress", 7)

    print(f"\nWrote {len(list(OUT.glob('*.png')))} screenshots to {OUT.relative_to(ROOT)}/")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except NeverAppeared as problem:
        print(f"\nStopped: {problem}")
        print("No screenshot was written for that step, rather than one of the wrong screen.")
        sys.exit(1)
