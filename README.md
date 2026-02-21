# Gjuha — Albanian Language Learning

> *gjuha* (Albanian) — *the language*

A Duolingo-scale Albanian language learning platform. iOS-native, offline-first, culturally immersive.

---

## Vision

The most modern, playful, and culturally rich Albanian learning experience in the world. Built for:

- Foreign partners of Albanians
- Albanian diaspora reconnecting with their roots
- Expats living in Albania
- Language learners drawn to Balkan languages

**Not a Duolingo clone. A new identity.**

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| Architecture | TCA (The Composable Architecture) |
| Local persistence | SwiftData |
| Content engine | Custom sentence generator + morphology rules |
| Distribution | App Store (iOS 17+) |

---

## Architecture

```
Gjuha/
├── App/                    # Entry point, AppReducer, root navigation
├── Features/               # TCA feature modules (self-contained)
│   ├── Onboarding/         # First-run flow, goal setting
│   ├── Home/               # Skill tree, daily lesson entry
│   ├── Lesson/             # Lesson session coordinator
│   ├── Exercise/           # All exercise types (MCQ, translate, listen, match)
│   ├── Vocabulary/         # Vocabulary browser + spaced repetition
│   ├── Grammar/            # Grammar reference + interactive tables
│   ├── Streak/             # Streak tracking + XP system
│   └── Profile/            # User stats, settings, preferences
├── Core/
│   ├── DesignSystem/       # Colors, typography, reusable components, animations
│   ├── Engine/             # Curriculum logic, sentence generator, scoring
│   ├── Extensions/         # Swift/SwiftUI extensions
│   └── Utilities/          # Helpers, constants
├── Data/
│   ├── Models/             # SwiftData model definitions
│   ├── Repositories/       # Data access layer (protocol + implementation)
│   ├── SwiftData/          # Schema, migrations, container setup
│   └── Seed/               # JSON datasets (vocabulary, lessons, grammar)
│       ├── Vocabulary/     # Word entries by CEFR level
│       ├── Lessons/        # Lesson metadata + exercise templates
│       └── Grammar/        # Morphology rules, conjugation tables
└── Resources/              # Assets, fonts, audio, localization
```

---

## Content Goals

| Metric | Target |
|--------|--------|
| Vocabulary entries | 4,000–6,000 |
| Verb conjugation dataset | Full paradigms |
| Noun declension patterns | All classes |
| Generated sentence variations | 30,000–60,000 |
| Structured lessons | 120+ |
| CEFR coverage | A1–B2 |

---

## Features Roadmap

### Phase 1 — Foundation (MVP)
- [ ] Skill tree home screen
- [ ] Lesson session engine
- [ ] Exercise types: multiple choice, translation, word match
- [ ] Core vocabulary dataset (A1: ~500 words)
- [ ] Streak + XP system
- [ ] SwiftData persistence

### Phase 2 — Content Depth
- [ ] Full A1 curriculum (30 lessons)
- [ ] Verb conjugation exercises
- [ ] Noun case exercises
- [ ] Audio pronunciation
- [ ] Grammar reference module

### Phase 3 — Engagement
- [ ] Spaced repetition vocabulary review
- [ ] Cultural immersion modules
- [ ] Achievements system
- [ ] Offline-first sync architecture

### Phase 4 — Scale
- [ ] A2 curriculum
- [ ] Backend + accounts
- [ ] Leaderboards
- [ ] Gheg dialect mode (optional)

---

## Development

### Requirements
- Xcode 16+
- iOS 17+ deployment target
- Swift 6

### Getting Started

```bash
git clone https://github.com/YOUR_USERNAME/gjuha.git
cd gjuha
open Gjuha.xcodeproj
```

### Key Dependencies
- [swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture) — TCA
- [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) — Dependency injection

---

## Design Principles

1. **Grammar transparency** — Explain the why, not just the what
2. **Cultural authenticity** — Real Albanian life, not textbook Albanian
3. **Minimal but energetic** — Premium aesthetic, not childish
4. **Offline-first** — Works without internet, always
5. **Content engine** — Generated exercises, not hardcoded sentences

---

## License

Private — All rights reserved. Not open source.
