import ComposableArchitecture
import Foundation

@Reducer
struct GrammarFeature {
    @ObservableState
    struct State: Equatable {
        var topics: [GrammarTopic] = []
        var selectedTopic: GrammarTopic? = nil
        var isLoading: Bool = false
    }

    enum Action {
        case onAppear
        case topicsLoaded([GrammarTopic])
        case topicSelected(GrammarTopic)
        case backTapped
    }

    @Dependency(\.grammarRepository) var grammarRepository

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading, state.topics.isEmpty else { return .none }
                state.isLoading = true
                return .run { send in
                    let topics = await grammarRepository.fetchTopics()
                    await send(.topicsLoaded(topics))
                }
            case .topicsLoaded(let topics):
                state.topics = topics
                state.isLoading = false
                return .none
            case .topicSelected(let topic):
                state.selectedTopic = topic
                return .none
            case .backTapped:
                state.selectedTopic = nil
                return .none
            }
        }
    }
}
