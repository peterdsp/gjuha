import ComposableArchitecture
import Foundation

@Reducer
struct GrammarFeature {
    @ObservableState
    struct State: Equatable {
        var topics: [GrammarTopic] = []
        var selectedTopic: GrammarTopic? = nil
        var isLoading: Bool = false
        var coach = CoachPanelState()

        /// Grammar coaching panel state for the selected topic. Kept separate from
        /// answer grading: this drives explanations only.
        struct CoachPanelState: Equatable {
            var availability: CoachAvailability = .unavailable(reason: "Not checked yet.")
            var result: CoachingResult? = nil
            var isGenerating: Bool = false
        }
    }

    enum Action {
        case onAppear
        case topicsLoaded([GrammarTopic])
        case topicSelected(GrammarTopic)
        case explainTapped(GrammarTopic, question: String)
        case coachResponse(CoachingResult)
        case backTapped
    }

    @Dependency(\.grammarRepository) var grammarRepository
    @Dependency(\.grammarCoach) var grammarCoach

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
                state.coach = State.CoachPanelState(availability: grammarCoach.aiAvailability())
                return .none
            case let .explainTapped(topic, question):
                guard !state.coach.isGenerating else { return .none }
                state.coach.isGenerating = true
                state.coach.availability = grammarCoach.aiAvailability()
                let grounding = CoachGrounding(topic: topic)
                let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
                return .run { send in
                    let result = await grammarCoach.explain(
                        CoachingInput(
                            grounding: grounding,
                            learnerQuestion: trimmed.isEmpty ? nil : trimmed
                        )
                    )
                    await send(.coachResponse(result))
                }
            case .coachResponse(let result):
                state.coach.isGenerating = false
                state.coach.result = result
                return .none
            case .backTapped:
                state.selectedTopic = nil
                state.coach = State.CoachPanelState()
                return .none
            }
        }
    }
}
