#!/usr/bin/env python3
"""Generate the Android string resources from the iOS String Catalog.

Gjuha ships the same app twice. Translating it twice would mean a native
reviewer reads two sets of Albanian that drift apart, and the second set would
be unreviewed the day it was written.

So the Android English is deliberately identical to the iOS key, and the
Albanian is copied verbatim from the catalog. One native review covers both
platforms, and a correction made on iOS reaches Android by re-running this.

    python3 Scripts/sync_android_strings.py          # write
    python3 Scripts/sync_android_strings.py --check  # fail if out of date

Not covered: the exercise prompts. Both platforms build those by interpolation
in their exercise engine rather than from a catalog, so they ship in English on
iOS too. That is a shared limitation, recorded in REMAINING_WORK.md, not an
Android gap.
"""
import json
import pathlib
import re
import sys
import xml.sax.saxutils as sx

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Gjuha/Resources/Localizable.xcstrings"
BASE = ROOT / "android/app/src/main/res/values/strings_generated.xml"
ALB = ROOT / "android/app/src/main/res/values-sq/strings_generated.xml"

# (android resource name, English, iOS catalog key supplying the Albanian)
MAPPING = [
    ("tab_learn", "Learn", "Learn"),
    ("tab_words", "Words", "Words"),
    ("tab_grammar", "Grammar", "Grammar"),
    ("tab_profile", "Profile", "Profile"),
    ("today", "Today", "Today"),
    ("day_streak", "Day streak", "Day streak"),
    ("total_xp", "Total XP", "Total XP"),
    ("words_seen", "Words seen", "Words seen"),
    ("lessons_done", "Lessons Done", "Lessons Done"),
    ("in_review", "In review", "In review"),
    ("mastered", "Mastered", "Mastered"),
    ("accuracy", "Accuracy", "Accuracy"),
    ("questions", "Questions", "Questions"),
    ("best_streak", "Best streak", "Best streak"),
    ("correct", "Correct!", "Correct!"),
    ("near_miss", "Almost, check the spelling", "Almost, check the spelling"),
    ("lesson_complete", "Lesson complete!", "Lesson complete!"),
    ("review_complete", "Review complete!", "Review complete!"),
    ("out_of_hearts", "Out of hearts!", "Out of hearts!"),
    ("achievements", "Achievements", "Achievements"),
    ("daily_goal", "Daily Goal", "Daily Goal"),
    ("continue_action", "Continue", "Continue"),
    ("check_action", "Check", "Check"),
    ("back_to_lessons", "Back to lessons", "Back to lessons"),
    ("start_learning", "Start learning", "Start learning"),
    ("examples", "Examples", "Examples"),
    ("practice_more", "Practice more to strengthen your memory.",
     "Practice more to strengthen your memory."),
    ("exit_lesson", "Exit lesson", "Exit lesson"),
    ("daily_review", "Daily review", "Daily review"),
    ("start_review", "Start Review", "Start Review"),
    ("search_words", "Search words...", "Search words..."),
    ("set_daily_goal", "Set your daily goal", "Set your daily goal"),
    ("goal_met", "Daily goal met", "Daily goal met"),
    ("locked_hint", "Complete all lessons above to unlock",
     "Complete all lessons above to unlock"),
    ("tagline", "Learn Albanian. Feel Albanian.", "Learn Albanian. Feel Albanian."),
    ("next_up", "Next: %1$s", "Next: %@"),
    ("xp_of", "%1$d/%2$d XP", "%lld/%lld XP"),
    ("lessons_of", "%1$d/%2$d lessons", "%lld/%lld lessons"),
    ("minutes_and_xp", "%1$d min/day · %2$d XP", "%lld min/day · %lld XP"),

    # Accessibility announcements. Reused from iOS so a screen reader says the
    # same thing on both platforms, in both languages.
    ("a11y_matched", "matched", "matched"),
    ("a11y_not_matched", "not matched", "not matched"),
    ("a11y_hearts_remaining", "Hearts remaining", "Hearts remaining"),
    ("a11y_lesson_progress", "Lesson progress", "Lesson progress"),
    ("a11y_unlocked", "Unlocked", "Unlocked"),
    ("a11y_progress", "Progress", "Progress"),
    ("a11y_start_review", "Starts a spaced repetition review session",
     "Starts a spaced repetition review session"),
    ("a11y_word_add", "Word %1$s, tap to add", "Word %@, tap to add"),
    ("a11y_word_remove", "Placed word %1$s, tap to remove",
     "Placed word %@, tap to remove"),
    ("a11y_locked_hint", "Complete all lessons above to unlock",
     "Complete all lessons above to unlock"),

    # Achievements. Keyed by the stable id rather than by the English, because
    # the id is what is persisted in the unlock ledger and the only thing that
    # must never change.
    ("ach_streak_3_title", "Three in a row", "Three in a row"),
    ("ach_streak_3_detail", "Study three days in a row.", "Study three days in a row."),
    ("ach_streak_7_title", "A full week", "A full week"),
    ("ach_streak_7_detail", "Study seven days in a row.", "Study seven days in a row."),
    ("ach_streak_30_title", "A month of Albanian", "A month of Albanian"),
    ("ach_streak_30_detail", "Study thirty days in a row.", "Study thirty days in a row."),
    ("ach_streak_100_title", "One hundred days", "One hundred days"),
    ("ach_streak_100_detail", "Study one hundred days in a row.",
     "Study one hundred days in a row."),
    ("ach_lessons_1_title", "First steps", "First steps"),
    ("ach_lessons_1_detail", "Finish your first lesson.", "Finish your first lesson."),
    ("ach_lessons_10_title", "Ten lessons in", "Ten lessons in"),
    ("ach_lessons_10_detail", "Finish ten lessons.", "Finish ten lessons."),
    ("ach_lessons_50_title", "Halfway to fluent", "Halfway to fluent"),
    ("ach_lessons_50_detail", "Finish fifty lessons.", "Finish fifty lessons."),
    ("ach_xp_500_title", "Five hundred XP", "Five hundred XP"),
    ("ach_xp_500_detail", "Earn 500 XP in total.", "Earn 500 XP in total."),
    ("ach_xp_2500_title", "Serious effort", "Serious effort"),
    ("ach_xp_2500_detail", "Earn 2,500 XP in total.", "Earn 2,500 XP in total."),
    ("ach_seen_100_title", "A hundred words", "A hundred words"),
    ("ach_seen_100_detail", "Meet 100 different Albanian words.",
     "Meet 100 different Albanian words."),
    ("ach_mastered_25_title", "Twenty-five kept", "Twenty-five kept"),
    ("ach_mastered_25_detail", "Carry 25 words to the long-term review interval.",
     "Carry 25 words to the long-term review interval."),
    ("ach_mastered_100_title", "One hundred kept", "One hundred kept"),
    ("ach_mastered_100_detail", "Carry 100 words to the long-term review interval.",
     "Carry 100 words to the long-term review interval."),
]

HEADER = """<?xml version="1.0" encoding="utf-8"?>
<!--
  Generated from the iOS String Catalog by Scripts/sync_android_strings.py.
  Do not hand edit: the English is deliberately identical to the iOS key so
  both apps show the same copy and one native review covers both.
-->
<resources>"""


def albanian(catalog, key):
    unit = catalog.get(key, {}).get("localizations", {}).get("sq", {}).get("stringUnit", {})
    return unit.get("value")


IOS_SPECIFIER = re.compile(r"%(?:(\d+)\$)?(?:lld|ld|d|@)")


def to_android_format(value):
    """Rewrite iOS format specifiers as Android ones.

    The catalog speaks Foundation: %lld for an integer and %@ for a string.
    Android's String.format speaks Java, where %lld is not a conversion at all
    and throws UnknownFormatConversionException at render time. Copying the
    Albanian verbatim therefore crashes the app, and only in Albanian, which is
    how it would have reached a user rather than a build.

    Every argument is numbered explicitly, because a translation is free to
    reorder them and an unnumbered Java format cannot express that.
    """
    counter = [0]

    def swap(match):
        explicit, text = match.group(1), match.group(0)
        counter[0] += 1
        index = int(explicit) if explicit else counter[0]
        kind = "s" if text.endswith("@") else "d"
        return f"%{index}${kind}"

    return IOS_SPECIFIER.sub(swap, value)


def specifier_shape(value):
    """The ordered argument types, for comparing two renderings of one string."""
    return [m[-1] for m in re.findall(r"%\d+\$([sd])", value)]


def escape(value):
    """Android resource escaping: XML entities, then the apostrophe."""
    return sx.escape(value).replace("'", "\\'")


def render(catalog, albanian_side):
    lines = [HEADER]
    for name, english, key in MAPPING:
        value = albanian(catalog, key) if albanian_side else english
        if value is None:
            continue
        if albanian_side:
            value = to_android_format(value)
        lines.append(f'    <string name="{name}">{escape(value)}</string>')
    lines.append("</resources>")
    return "\n".join(lines) + "\n"


ACHIEVEMENTS = ROOT / "android/core/src/main/kotlin/com/gjuha/core/Achievement.kt"


def achievement_ids():
    """Ids declared in the shared catalogue, in declaration order."""
    source = ACHIEVEMENTS.read_text()
    return re.findall(r'Achievement\("([^"]+)"', source)


def resource_stem(achievement_id):
    """streak.3 -> ach_streak_3, so a mapping can be found from an id."""
    return "ach_" + achievement_id.replace(".", "_")


def check_achievements(names):
    """Every milestone must have a localized title and detail.

    Adding one to the catalogue and forgetting its strings is silent: the row
    falls back to the core's English and only an Albanian speaker would notice,
    which is exactly the mixed-language screen this whole file exists to avoid.
    """
    missing = []
    for achievement_id in achievement_ids():
        stem = resource_stem(achievement_id)
        for suffix in ("title", "detail"):
            if f"{stem}_{suffix}" not in names:
                missing.append(f"{stem}_{suffix}")
    return missing


def main():
    catalog = json.loads(CATALOG.read_text())["strings"]

    names = {name for name, _, _ in MAPPING}
    unmapped = check_achievements(names)
    if unmapped:
        print("Achievements with no localized name: " + ", ".join(unmapped))
        print("Add them to MAPPING and to AchievementStrings.kt.")
        return 1

    untranslated = [k for _, _, k in MAPPING if not albanian(catalog, k)]
    if untranslated:
        print("No Albanian in the catalog for: " + ", ".join(repr(k) for k in untranslated))
        return 1

    # The two renderings must take the same arguments in the same order, or one
    # locale formats correctly and the other throws.
    mismatched = []
    for name, english, key in MAPPING:
        alb = albanian(catalog, key)
        if alb is None:
            continue
        if specifier_shape(english) != specifier_shape(to_android_format(alb)):
            mismatched.append(name)
    if mismatched:
        print("Format arguments differ between English and Albanian for: "
              + ", ".join(mismatched))
        return 1

    wanted = {BASE: render(catalog, False), ALB: render(catalog, True)}

    if "--check" in sys.argv:
        stale = [p for p, text in wanted.items()
                 if not p.exists() or p.read_text() != text]
        if stale:
            print("Out of date, re-run Scripts/sync_android_strings.py:")
            for p in stale:
                print("  " + str(p.relative_to(ROOT)))
            return 1
        print(f"Android strings match the iOS catalog ({len(MAPPING)} strings).")
        return 0

    for path, text in wanted.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    print(f"Wrote {len(MAPPING)} strings, Albanian reused from the iOS catalog.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
