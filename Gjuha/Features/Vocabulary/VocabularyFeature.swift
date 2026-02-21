import ComposableArchitecture
import Foundation

@Reducer
struct VocabularyFeature {
    @ObservableState
    struct State: Equatable {
        var words: [Word] = []
        var searchQuery: String = ""
        var selectedCEFR: CEFRLevel? = nil
        var isLoading: Bool = false

        var filteredWords: [Word] {
            words.filter { word in
                let matchesSearch = searchQuery.isEmpty ||
                    word.albanian.localizedCaseInsensitiveContains(searchQuery) ||
                    word.english.localizedCaseInsensitiveContains(searchQuery)
                let matchesCEFR = selectedCEFR == nil || word.cefrLevel == selectedCEFR
                return matchesSearch && matchesCEFR
            }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case wordsLoaded([Word])
        case cefrFilterTapped(CEFRLevel?)
    }

    @Dependency(\.vocabularyRepository) var vocabularyRepository

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let words = await vocabularyRepository.fetchAll()
                    await send(.wordsLoaded(words))
                }
            case .wordsLoaded(let words):
                state.words = words
                state.isLoading = false
                return .none
            case .cefrFilterTapped(let level):
                state.selectedCEFR = level
                return .none
            case .binding:
                return .none
            }
        }
    }
}
