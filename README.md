<div align="center">

# gjuha

### *gjuha* (Albanian) - *the language*

**The most modern Albanian language learning experience ever built.**

iOS-native · Offline-first · Culturally immersive · A1 → B2

<br>

[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-26-147EFB?style=flat-square&logo=xcode&logoColor=white)](https://developer.apple.com/xcode/)
[![iOS](https://img.shields.io/badge/iOS-17%2B-000000?style=flat-square&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![TCA](https://img.shields.io/badge/TCA-1.23-6B4EFF?style=flat-square)](https://github.com/pointfreeco/swift-composable-architecture)
[![License](https://img.shields.io/badge/License-Private-red?style=flat-square)]()

</div>

---

## What is Gjuha?

Albanian is spoken by 8 million people. It has no major learning app. No Duolingo course. No Rosetta Stone. No Babbel.

**Gjuha is here to change that.**

Built for the foreign partners of Albanians, the diaspora reconnecting with their roots, the expats living in Tirana, and the language nerds drawn to one of the oldest surviving Indo-European languages on earth.

This is not a hobby project. It is a long-term platform designed to reach **Duolingo-scale depth** - A1 through B2 - with better grammar transparency, real cultural immersion, and an engine that generates exercises rather than hardcoding sentences.

---

## Features

```
✦  Skill tree home screen          ✦  Verb conjugation exercises
✦  Lesson session engine           ✦  Noun declension system
✦  Multiple choice exercises       ✦  Grammar reference tables
✦  Translation input               ✦  Fill-in-the-blank
✦  Word matching                   ✦  Spaced repetition (planned)
✦  Streak + XP system              ✦  Cultural immersion modules (planned)
✦  Offline-first - always works    ✦  Audio pronunciation (planned)
✦  Dark mode adaptive UI           ✦  Gheg dialect mode (planned)
```

---

## Tech Stack

| Layer | Choice | Why |
|-------|--------|-----|
| **UI** | SwiftUI | Native, declarative, fast |
| **Architecture** | TCA 1.23 | Unidirectional, testable, composable |
| **Persistence** | SwiftData | First-class iOS 17 ORM |
| **DI** | swift-dependencies | Mockable, testable, TCA-native |
| **Content** | Custom engine + JSON seed | Generated exercises, not hardcoded |
| **Distribution** | App Store | iOS 17+ |

---

## Architecture

The project uses **The Composable Architecture (TCA)** with strict feature isolation. Every screen is a self-contained reducer module.

```
Gjuha/
├── App/                        # @main, AppFeature, root NavigationStack
│
├── Features/                   # Self-contained TCA modules
│   ├── Onboarding/             # Goal setting, reason selection
│   ├── Home/                   # Skill tree, streak header, lesson nodes
│   ├── Lesson/                 # Session coordinator (hearts, progress, XP)
│   ├── Exercise/               # MCQ, translate, fill-blank, match
│   ├── Vocabulary/             # Browser with CEFR filter + search
│   ├── Grammar/                # Reference tables + conjugation viewer
│   ├── Streak/                 # Streak logic + XP tracking
│   └── Profile/                # Stats dashboard, daily goal picker
│
├── Core/
│   ├── DesignSystem/           # GjuhaColors, GjuhaFonts, shared components
│   ├── Engine/                 # Exercise generator, scoring, curriculum
│   ├── Extensions/             # Swift + SwiftUI extensions
│   └── Utilities/              # Constants, helpers
│
├── Data/
│   ├── Models/                 # SwiftData @Model classes (Word, Lesson)
│   ├── Repositories/           # Protocol + Live + Mock implementations
│   ├── SwiftData/              # Schema, container, migrations
│   └── Seed/                   # JSON datasets - the content engine fuel
│       ├── Vocabulary/         # word_frequency_top6000.csv + curated entries
│       ├── Lessons/            # Unit + lesson definitions
│       └── Grammar/            # Morphology rules, conjugation tables
│
└── Resources/
    ├── Assets.xcassets/        # 14 adaptive color pairs (light + dark)
    ├── Audio/                  # Pronunciation files (planned)
    └── Fonts/                  # Custom typeface (planned)
```

### Key Architectural Decisions

**TCA everywhere.** No MVVM, no Combine, no ViewModels. Every screen is a `@Reducer` with typed `State`, `Action`, and an `Effect`-based body.

**Value types in State.** SwiftData `@Model` classes never enter TCA State. `LessonSummary` is a `Sendable` value type that mirrors `Lesson` for use in reducers - keeping Swift 6 strict concurrency clean throughout.

**Protocol-based repositories.** Every data source is behind a `protocol: Sendable` with a `Live` implementation and a `Mock` for tests and previews. Wired via `@Dependency`.

**Content engine, not hardcoded sentences.** All exercises are generated from seed data (vocabulary + templates + morphology rules). No exercise is written by hand.

---

## Content Dataset

The content pipeline is already running:

| Dataset | Status | Size |
|---------|--------|------|
| Curated vocabulary (bundled, used by the engine) | ✅ Done | 350 entries in `a1_vocabulary.json` (mostly A1, some A2) |
| Frequency-seeded vocabulary CSV (pipeline) | 🔄 In progress | 600 rows, some still `__TODO__` placeholders |
| Word frequency list | ✅ Generated | Top 6,000 from Tatoeba corpus |
| Albanian sentence corpus | ✅ Generated | ~2,600 sentences (sqi) |
| Sentence templates | ✅ Done | 300 templates |
| Exercise seed (pipeline artifact, not loaded at runtime) | ✅ Done | 1,000 exercises |
| Morphology rules | ✅ Done | Verb + noun patterns |
| A1-B1 curriculum plan | ✅ Done | 120 lessons across 12 units |
| Grammar topic dataset | 🔄 In progress | Conjugation tables, case rules |
| Audio recordings | 📋 Planned | Phase 2 |

**Target vocabulary:** 4,000-6,000 entries covering A1-B2.
**Target exercises:** 30,000-60,000 generated variations.

> **Runtime note.** At runtime the exercise engine generates multiple-choice,
> typed-translation and fill-in-the-blank exercises from `a1_vocabulary.json`.
> The 1,000-exercise seed and the sentence/frequency CSVs are content-pipeline
> artifacts that are not yet loaded by the app. The curated A1 dataset does not
> yet populate `gender` or `verbClass`, so exercise generation relies on
> `partOfSpeech`, `cefrLevel` and `frequency` (see the Phase 0 notes below).

### Content Pipeline

```bash
# Pull open datasets (Tatoeba + Wiktionary + Leipzig)
bash Scripts/tools/fetch_sources.sh

# Generate frequency list + sentence corpus
python3 Scripts/tools/build_from_sources.py

# Output:
#   Gjuha/Data/Seed/Vocabulary/word_frequency_top6000.csv
#   Gjuha/Data/Seed/sentences_sqi_50k.csv
```

---

## Learning Experience Behavior

Verified runtime behavior of the core lesson flow (Phase 0 foundations):

- **Stable options.** Answer choices keep a fixed order for the life of an
  exercise. Feedback and unrelated state changes never reshuffle them.
- **Plausible distractors.** Multiple-choice distractors are chosen from
  vocabulary metadata (same part of speech, then CEFR level, then nearest
  frequency), never at random. Options that would also be correct, or that
  duplicate another option, are excluded. A small curated fallback keeps every
  question answerable when the pool is too small.
- **Meaning-preserving grading.** Typed answers are compared after trimming,
  whitespace collapse, case folding and Unicode (NFC) normalization. Albanian
  diacritics (ë, ç) and articles are required: dropping them is surfaced as a
  *near miss* with targeted feedback, never accepted as correct.
- **Honest feedback.** After each answer the app shows the actual XP awarded
  (including combo bonus) and the exercise explanation when one exists.
- **Honest stats.** Profile shows "Words seen", the distinct vocabulary covered
  by completed lessons (exposure, not mastery), alongside streak, XP and lessons
  completed read from stored progress.
- **Persisted goal.** The daily goal chosen during onboarding is saved and
  restored on relaunch.
- **Accessible.** The lesson flow supports Dynamic Type, exposes VoiceOver
  labels and focus order, and signals correct / near-miss / incorrect with icons
  and text rather than color alone.

---

## Albanian - Why It's Interesting

Albanian is one of the oldest surviving branches of Indo-European - an entire branch unto itself, not a sub-family. It has no close living relatives.

```
mirëdita        →  good day (mirë + ditë - "good" + "day")
faleminderit    →  thank you (via Ottoman Turkish, from Arabic)
ju lutem        →  please / you're welcome
shtëpi          →  house (one of the oldest IE root words still in use)
```

It features **postposed definite articles** (the article attaches to the end of the noun), **five grammatical cases**, **two major dialects** (Tosk in the south, Gheg in the north), and verb moods that most Western learners have never encountered.

Gjuha teaches all of it - clearly, progressively, with cultural context.

---

## Curriculum Plan

12 units · 120 lessons · A1 → B2

```
Unit 01  - Survival Basics        [A1]  Greetings, pronouns, to be/have
Unit 02  - Everyday Life          [A1]  Work, transport, health, market
Unit 03  - Talking About You      [A1]  People, adjectives, past tense
Unit 04  - Getting Around         [A2]  Directions, places, plans
Unit 05  - People & Relationships [A2]  Family, feelings, social life
Unit 06  - Language in Action     [A2]  Opinions, requests, comparison
Unit 07  - Albanian Society       [B1]  Culture, media, current affairs
Unit 08  - Work & Ambition        [B1]  Career, formal register
Unit 09  - Nature & Environment   [B1]  Climate, geography, seasons
Unit 10  - Deeper Connections     [B1]  Abstract emotions, storytelling
Unit 11  - Fluency Building       [B2]  Idioms, nuance, debate
Unit 12  - Cultural Mastery       [B2]  Literature, history, identity
```

---

## Design System

A semantic token system built around Albanian character - not borrowed from Duolingo.

```swift
// Colors
Color.gjuha.accent          // Deep Albanian red - primary actions
Color.gjuha.streak          // Flame orange - motivation layer
Color.gjuha.xp              // Gold - reward moments
Color.gjuha.background      // Off-white / near-black (adaptive)
Color.gjuha.surface         // Card background (adaptive)

// Typography
Font.gjuha.displayLarge     // 48pt Black Rounded - hero moments
Font.gjuha.headingLarge     // 28pt Bold Rounded - screen titles
Font.gjuha.exercisePrompt   // 26pt Semibold - the question
Font.gjuha.answerOption     // 18pt Medium - tappable answers
Font.gjuha.bodyRegular      // 16pt Regular - body copy
```

All 14 colors are defined as named asset pairs with automatic light/dark variants.
All spacing follows a strict **4pt grid** (4, 8, 12, 16, 24, 32, 48).

---

## Roadmap

### Phase 1 - Foundation *(current)*
- [x] Project scaffold - TCA feature modules for all 8 screens
- [x] SwiftData schema (Word, Lesson)
- [x] Repository layer - protocol + live + mock for all domains
- [x] Exercise engine foundation (MCQ, translate, fill-blank)
- [x] Design system - 14 semantic color tokens, typography scale
- [x] A1 vocabulary seed + curriculum dataset (120 lessons planned)
- [x] Content pipeline - Tatoeba + Wiktionary data processing
- [ ] Skill tree home screen (UI)
- [ ] Working lesson session end-to-end
- [ ] SwiftData seed loader from JSON
- [ ] App Store submission

### Phase 2 - Content Depth
- [ ] Full A1 curriculum (30 lessons)
- [ ] Verb conjugation exercise type
- [ ] Noun case system exercises
- [ ] Grammar reference module
- [ ] Audio pronunciation

### Phase 3 - Engagement
- [ ] Spaced repetition vocabulary review
- [ ] Streak mechanics + daily notifications
- [ ] Achievements system
- [ ] Cultural immersion modules

### Phase 4 - Scale
- [ ] A2 full curriculum
- [ ] Remote content packs (downloadable A2, B1)
- [ ] User accounts + sync
- [ ] Gheg dialect mode

---

## Getting Started

```bash
# Requirements: Xcode 26+, iOS 17+ simulator

git clone https://github.com/pdhespollari/gjuha.git
cd gjuha
open Gjuha.xcodeproj
```

On first build, Xcode will ask to trust TCA macros - click **Trust & Enable Macros**, then run.

### Regenerate the Xcode project

The project is spec-managed with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate --spec project.yml
```

### Run the content pipeline

```bash
# 1. Download open datasets (~1.8 GB total - Tatoeba + Wiktionary)
bash Scripts/tools/fetch_sources.sh

# 2. Build frequency list + sentence corpus
python3 Scripts/tools/build_from_sources.py
```

---

## Design Principles

**Grammar transparency.**
Albanian grammar is complex and systematic. Gjuha explains the *why* - declension cases, verb moods, definiteness - not just the surface forms. Better than Duolingo's surface-level approach.

**Cultural authenticity.**
Real Albanian life: coffee culture, *besa* (the code of honour), *xhiro* (the evening walk), regional identity, hospitality. Not textbook sentences about going to the library.

**Minimal but energetic.**
Premium aesthetic. Not childish. Not a Duolingo reskin. A distinct identity built for adults who take language seriously.

**Offline-first.**
The full core course lives in the app bundle. Works on a plane. Works in Shkodër with no signal. Always.

**Content engine.**
One vocabulary entry powers dozens of exercise variations. The engine generates from templates × morphology rules × vocabulary. No content is written by hand.

---

## License

Private - All rights reserved. © 2026 Gjuha.
