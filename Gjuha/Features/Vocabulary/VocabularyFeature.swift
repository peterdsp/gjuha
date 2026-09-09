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
        /// Whether an on-device Albanian voice is available to fall back to when a
        /// word has no bundled clip. Together with `word.audioFileName` this drives
        /// whether a word shows a play control. Set once on appear.
        var canSpeakAlbanian: Bool = false

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
        case playPronunciation(Word)
    }

    @Dependency(\.vocabularyRepository) var vocabularyRepository
    @Dependency(\.audioPlayer) var audioPlayer

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.canSpeakAlbanian = audioPlayer.albanianVoiceAvailable
                guard !state.isLoading, state.words.isEmpty else { return .none }
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
            case .playPronunciation(let word):
                let url = word.audioFileName.flatMap { AudioLibrary.shared.url(forFile: $0) }
                let text = word.albanian
                return .run { _ in
                    await audioPlayer.playOrSpeak(url: url, albanianText: text)
                }
            case .binding:
                return .none
            }
        }
    }
}
