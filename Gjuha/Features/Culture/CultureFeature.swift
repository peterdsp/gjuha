import ComposableArchitecture
import Foundation

// MARK: - Culture hub (list)

/// The learner-facing entry point for distinctive Albanian content: cultural
/// units and labeled regional (dialect) packs.
///
/// Content is driven entirely by `ContentCatalog`'s PRODUCTION accessors, which
/// return only natively reviewed items. In a normal build both are empty, so the
/// hub shows an honest "in review" empty state rather than any unreviewed
/// language. The flows themselves (this hub, the detail screens, the practice
/// session, and the progress it feeds) are real and are exercised with isolated
/// `nativeReviewed` fixtures (see `LiveContentCatalog.cultureFixtureCatalog`),
/// never by shipping unreviewed content.
@Reducer
struct CultureFeature {
    @ObservableState
    struct State: Equatable {
        var culturalUnits: [CulturalUnit] = []
        var dialectPacks: [DialectContentPack] = []
        var isLoading: Bool = false
        var hasLoaded: Bool = false

        /// True once content has loaded and nothing passed native review yet, so
        /// the view can explain why the hub is empty without implying failure.
        var showsEmptyState: Bool {
            hasLoaded && culturalUnits.isEmpty && dialectPacks.isEmpty
        }
    }

    enum Action {
        case onAppear
        case contentLoaded(units: [CulturalUnit], packs: [DialectContentPack])
        /// Bubble up to the parent, which pushes the detail onto the shared stack.
        case unitTapped(CulturalUnit)
        case packTapped(DialectContentPack)
    }

    @Dependency(\.contentCatalog) var contentCatalog

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.hasLoaded else { return .none }
                state.isLoading = true
                return .run { send in
                    let units = await contentCatalog.productionCulturalUnits()
                    let packs = await contentCatalog.productionDialectPacks()
                    await send(.contentLoaded(units: units, packs: packs))
                }

            case let .contentLoaded(units, packs):
                state.culturalUnits = units
                state.dialectPacks = packs
                state.isLoading = false
                state.hasLoaded = true
                return .none

            case .unitTapped, .packTapped:
                // Navigation is owned by the parent (AppFeature), which appends the
                // detail screen to the shared navigation stack.
                return .none
            }
        }
    }
}

// MARK: - Cultural unit detail

/// Presents a single cultural unit: its framing, the vocabulary it reuses, the
/// grammar it reinforces, and its listening lines, plus a button to practise the
/// unit's words through the normal spaced repetition session.
@Reducer
struct CulturalUnitFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        var unit: CulturalUnit
        var vocabulary: [VocabularyLine] = []
        var id: String { unit.id }

        init(unit: CulturalUnit, vocabulary: [VocabularyLine] = []) {
            self.unit = unit
            self.vocabulary = vocabulary
        }
    }

    enum Action {
        case onAppear
        case vocabularyLoaded([VocabularyLine])
        /// Carries the word ids to practise so the parent can push a review
        /// session over them without re-reading the unit.
        case practiceTapped([String])
    }

    @Dependency(\.exerciseEngine) var exerciseEngine

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.vocabulary.isEmpty else { return .none }
                let ids = state.unit.vocabularyIds
                return .run { send in
                    let lines = await exerciseEngine.vocabularyLines(forWordIds: ids)
                    await send(.vocabularyLoaded(lines))
                }

            case let .vocabularyLoaded(lines):
                state.vocabulary = lines
                return .none

            case .practiceTapped:
                // Handled by the parent, which pushes a review session.
                return .none
            }
        }
    }
}

// MARK: - Dialect pack detail

/// Presents a labeled dialect pack: standard versus regional forms with usage
/// notes. Dialect forms are reference content, never graded as right or wrong,
/// so there is no exercise here, only presentation.
@Reducer
struct DialectPackFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        var pack: DialectContentPack
        var id: String { pack.id }
    }

    enum Action {
        case onAppear
    }

    var body: some ReducerOf<Self> {
        Reduce { _, _ in .none }
    }
}
