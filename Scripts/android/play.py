#!/usr/bin/env python3
"""Plays a Gjuha lesson on a connected emulator by reading the screen.

Answers come from the shipped seed and every tap is the centre of a bound that
uiautomator reported, so a layout change cannot quietly make this press the
wrong thing. Used by the screenshot capture, and useful on its own for driving
the app to a known state.

    python3 Scripts/android/play.py            # play one lesson
    python3 Scripts/android/play.py --serial emulator-5556

Two things about reading the screen that are easy to get wrong:

- uiautomator switches an attribute to SINGLE quotes when its value contains a
  double quote, which the word order prompt always does. A regex over
  `text="..."` silently loses exactly that prompt, so this parses real XML.
- `adb shell input text` raises on any non-ASCII character, so an Albanian
  answer carrying e-diaeresis cannot be typed at all. It is folded to ASCII,
  which is what a learner who cannot find the key types, so the app grades it
  a near miss. That costs a heart and is expected, not a failure.
"""
import argparse
import json
import pathlib
import re
import subprocess
import sys
import time
import unicodedata
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
SEED = ROOT / "Gjuha/Data/Seed/Vocabulary/a1_vocabulary.json"

PACKAGE = "com.gjuha.app"
ACTIVITY = f"{PACKAGE}/.MainActivity"


class Device:
    def __init__(self, serial):
        self.adb = ["adb"] + (["-s", serial] if serial else [])

    def sh(self, *args):
        return subprocess.run(self.adb + list(args), capture_output=True, text=True).stdout

    def tap(self, x, y, settle=0.9):
        self.sh("shell", "input", "tap", str(x), str(y))
        time.sleep(settle)

    def type(self, text):
        self.sh("shell", "input", "text", text.replace(" ", "%s"))

    def screen(self):
        """The screen as a list of labelled elements with tap points."""
        self.sh("shell", "uiautomator", "dump", "/sdcard/ui.xml")
        xml = self.sh("shell", "cat", "/sdcard/ui.xml")
        if "<hierarchy" not in xml:
            return []
        root = ET.fromstring(xml[xml.index("<hierarchy"):].strip())
        out = []
        for node in root.iter("node"):
            text = node.get("text") or ""
            if not text:
                continue
            box = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
            if not box:
                continue
            x1, y1, x2, y2 = map(int, box.groups())
            out.append({
                "text": text,
                "cx": (x1 + x2) // 2,
                "cy": (y1 + y2) // 2,
                "y1": y1,
            })
        return out

    def capture(self, path):
        raw = subprocess.run(self.adb + ["exec-out", "screencap", "-p"], capture_output=True).stdout
        pathlib.Path(path).write_bytes(raw)
        return len(raw)


def head(text):
    """The part of a gloss before any slash or bracket, as a match tile shows it."""
    return text.split("/")[0].split("(")[0].strip()


def fold(text):
    """ASCII fold, because adb cannot type Albanian diacritics."""
    return "".join(c for c in unicodedata.normalize("NFD", text)
                   if unicodedata.category(c) != "Mn")


class Lexicon:
    def __init__(self):
        words = json.loads(SEED.read_text())
        self.alb_to_eng = {w["albanian"].lower(): w["english"] for w in words}
        self.eng_to_alb = {}
        for w in words:
            self.eng_to_alb.setdefault(head(w["english"]).lower(), w["albanian"])
            self.eng_to_alb.setdefault(w["english"].lower(), w["albanian"])
        self.sentence_for = {
            (w.get("exampleTranslation") or "").strip().lower(): w.get("exampleSentence") or ""
            for w in words if w.get("exampleTranslation")
        }
        self.words = words


# The question formats the engine produces. A prompt is whatever matches one of
# these, which is independent of layout, language of the chrome, and length.
PROMPT_SHAPES = [
    re.compile(r"What does '(.+?)' mean\?"),
    re.compile(r"How do you say '(.+?)' in Albanian\?"),
    re.compile(r"Translate: '(.+?)'"),
    re.compile(r'Arrange the words to say: "(.+?)"'),
    re.compile(r"___"),
]


def find(elements, text):
    return next((e for e in elements if e["text"] == text), None)


def answer_once(device, lexicon, elements, verbose):
    texts = [e["text"] for e in elements]

    def say(message):
        if verbose:
            print(f"    {message}")

    # The prompt is found by its shape, not by where it sits or how long it is.
    #
    # Both positional guesses failed. "First longish string near the top" picked
    # the exit button, which in Albanian reads "Dil nga mësimi" and is longer
    # than the English. "Longest string in the prompt band" then picked an
    # ANSWER, because "will (future particle)" is longer than
    # "What does 'po' mean?" and the first option sits inside any band wide
    # enough to hold a two line prompt.
    prompt = next(
        (t for t in texts if any(pattern.search(t) for pattern in PROMPT_SHAPES)),
        "",
    )

    if any("Match each word" in t for t in texts):
        for left in [e for e in elements if e["cx"] < 540 and e["text"].lower() in lexicon.alb_to_eng]:
            want = head(lexicon.alb_to_eng[left["text"].lower()]).lower()
            right = [e for e in elements if e["cx"] > 540 and head(e["text"]).lower() == want]
            if not right:
                continue
            say(f"match {left['text']!r}")
            device.tap(left["cx"], left["cy"])
            device.tap(right[0]["cx"], right[0]["cy"])
            elements = device.screen()
        return True

    match = re.search(r"What does '(.+?)' mean\?", prompt)
    if match:
        want = head(lexicon.alb_to_eng.get(match.group(1).lower(), "")).lower()
        for element in elements:
            if head(element["text"]).lower() == want and element["y1"] > 350:
                say(f"{match.group(1)!r} -> {element['text']!r}")
                device.tap(element["cx"], element["cy"])
                return True
        return False

    match = re.search(r"How do you say '(.+?)' in Albanian\?", prompt)
    if match:
        element = find(elements, lexicon.eng_to_alb.get(match.group(1).lower(), ""))
        if element:
            say(f"{match.group(1)!r} -> {element['text']!r}")
            device.tap(element["cx"], element["cy"])
            return True
        return False

    match = re.search(r"Translate: '(.+?)'", prompt)
    if match:
        source = match.group(1)
        to_albanian = any("Type in Albanian" in t for t in texts)
        answer = (lexicon.eng_to_alb.get(source.lower(), "") if to_albanian
                  else head(lexicon.alb_to_eng.get(source.lower(), "")))
        field = next((e for e in elements if "Type in" in e["text"]), None)
        if not (answer and field):
            return False
        device.tap(field["cx"], field["cy"])
        typed = fold(answer)
        if typed != answer:
            say(f"folded {answer!r} -> {typed!r}, adb cannot type it")
        device.type(typed)
        time.sleep(0.5)
        check = find(device.screen(), "Check")
        if check:
            device.tap(check["cx"], check["cy"])
        return True

    match = re.search(r'Arrange the words to say: "(.+?)"', prompt)
    if match:
        sentence = lexicon.sentence_for.get(match.group(1).strip().lower(), "")
        if not sentence:
            return False
        for token in sentence.split():
            current = device.screen()
            candidates = [e for e in current if e["text"] == token and e["y1"] > 400]
            if not candidates:
                return False
            device.tap(candidates[0]["cx"], candidates[0]["cy"])
        check = find(device.screen(), "Check")
        if check:
            say(f"arranged {sentence!r}")
            device.tap(check["cx"], check["cy"])
        return True

    if "___" in prompt:
        for word in lexicon.words:
            translation = (word.get("exampleTranslation") or "").strip()
            if translation and translation.lower() in prompt.lower():
                element = find(elements, word["albanian"])
                if element:
                    device.tap(element["cx"], element["cy"])
                    return True
        return False

    return False


def signature(elements):
    """Enough of the screen to tell one question from the next."""
    return tuple(sorted(e["text"] for e in elements))


def wait_for_change(device, before, timeout=8.0):
    """Waits until the screen is no longer the one just answered.

    A fixed sleep is not enough. The feedback banner holds the question on
    screen for a moment, and answering again from that stale screen re-enters
    the same exercise. For word order that is actively harmful: placed tokens
    stay tappable so they can be taken back, so a second pass REMOVES them and
    submits a wrong answer.
    """
    deadline = time.time() + timeout
    while time.time() < deadline:
        time.sleep(0.6)
        current = device.screen()
        if current and signature(current) != before:
            return current
    return device.screen()


def play_lesson(device, lexicon, limit=16, verbose=True, on_screen=None):
    """Answers until the session ends. Returns True if it reached completion."""
    elements = device.screen()
    for step in range(limit):
        joined = " ".join(e["text"] for e in elements)
        if "Lesson complete" in joined or "Review complete" in joined:
            if verbose:
                xp = next((e["text"] for e in elements if e["text"].startswith("+")), "?")
                print(f"  complete {xp}")
            return True
        if "Out of hearts" in joined:
            print("  out of hearts")
            return False
        if on_screen:
            on_screen(step, elements)

        before = signature(elements)
        if not answer_once(device, lexicon, elements, verbose):
            print(f"  stuck at step {step}: {joined[:160]}")
            return False
        elements = wait_for_change(device, before)
    return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--serial", default="emulator-5554")
    args = parser.parse_args()
    device = Device(args.serial)
    return 0 if play_lesson(device, Lexicon()) else 1


if __name__ == "__main__":
    sys.exit(main())
