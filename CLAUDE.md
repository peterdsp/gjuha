# CLAUDE.md - Gjuha Project Guide

This file defines conventions, architecture decisions, and working rules for AI-assisted development on this project.

---

## Project Identity

**Gjuha** is an iOS Albanian language learning app.
- iOS-native SwiftUI + TCA (The Composable Architecture)
- Offline-first with SwiftData
- Content engine driven (not hardcoded sentences)
- Solo founder project - prioritize simplicity and scalability over cleverness

---

## Architecture Rules

### TCA Feature Module Pattern

Every feature follows this structure:

```swift
// Feature/SomeFeature/SomeFeature.swift
@Reducer
struct SomeFeature {
    @ObservableState
    struct State: Equatable { ... }

    enum Action { ... }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            // logic
        }
    }
}

// Feature/SomeFeature/Views/SomeView.swift
struct SomeView: View {
    let store: StoreOf<SomeFeature>
    var body: some View { ... }
}
```

### Naming Conventions

- Feature reducers: `FeatureNameFeature` (e.g., `LessonFeature`, `HomeFeature`)
- Views: `FeatureNameView` (e.g., `LessonView`, `HomeView`)
- Models: plain structs/classes, no suffix (e.g., `Word`, `Lesson`, `Exercise`)
- SwiftData models: suffix with `Model` only if ambiguous with domain type (e.g., `UserProgressModel`)
- Repositories: `SomethingRepository` protocol + `LiveSomethingRepository` implementation

### Dependency Injection

Use `@Dependency` from swift-dependencies for all external dependencies:

```swift
extension DependencyValues {
    var vocabularyRepository: any VocabularyRepository {
        get { self[VocabularyRepositoryKey.self] }
        set { self[VocabularyRepositoryKey.self] = newValue }
    }
}
```

---

## File Organization Rules

- Each TCA feature lives in its own folder under `Features/`
- Keep `State`, `Action`, `Reducer` body in one file unless it exceeds ~200 lines
- Views always in a `Views/` subfolder within the feature
- No business logic in Views - all logic in reducers
- Data models in `Data/Models/`, never in feature folders

---

## Content Engine Rules

- Exercises are generated from templates + dataset, never hardcoded
- All seed data lives in `Data/Seed/` as JSON files
- Vocabulary entries must include: Albanian word, English translation, CEFR level, gender (for nouns), verb class (for verbs), example sentence
- Lessons reference vocabulary IDs and grammar rule IDs, not inline content

---

## Design System Rules

- All colors via `Color.gjuha.*` (defined in `Core/DesignSystem/Colors/`)
- All fonts via `Font.gjuha.*` (defined in `Core/DesignSystem/Typography/`)
- No hardcoded colors or font sizes in Views
- Spacing uses 4pt grid: 4, 8, 12, 16, 24, 32, 48

---

## Do Not

- Do not use Combine - use TCA Effects and async/await only
- Do not add backend networking until Phase 3
- Do not hardcode exercise content - always drive from dataset
- Do not use MVVM - we use TCA exclusively
- Do not add third-party dependencies without documenting why

---

## Testing Conventions

- Unit test all reducers in `GjuhaTests/`
- Use `TestStore` from TCA for reducer tests
- UI tests for critical user flows only
- Test files mirror the feature structure

---

## Current Phase

**Phase 1 - Foundation**

Focus: Core TCA architecture, basic exercise engine, A1 vocabulary dataset, SwiftData persistence.
