import ComposableArchitecture
import Foundation

@Reducer
struct OnboardingFeature {
    @ObservableState
    struct State: Equatable {
        var step: Step = .welcome
        var selectedGoal: LearningGoal = .casual
        var selectedReason: LearningReason = .partner

        enum Step: Int, Equatable, CaseIterable {
            case welcome
            case reason
            case goal
        }
    }

    enum Action {
        case nextStepTapped
        case goalSelected(LearningGoal)
        case reasonSelected(LearningReason)
        case completed
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .nextStepTapped:
                if state.step == .goal {
                    return .send(.completed)
                }
                let allSteps = State.Step.allCases
                if let currentIdx = allSteps.firstIndex(of: state.step),
                   currentIdx + 1 < allSteps.count {
                    state.step = allSteps[currentIdx + 1]
                }
                return .none

            case .goalSelected(let goal):
                state.selectedGoal = goal
                return .none

            case .reasonSelected(let reason):
                state.selectedReason = reason
                return .none

            case .completed:
                return .none
            }
        }
    }
}

enum LearningGoal: String, Equatable, CaseIterable {
    case casual = "casual"       // 5 min/day
    case regular = "regular"     // 10 min/day
    case serious = "serious"     // 15 min/day
    case intense = "intense"     // 20 min/day

    var displayName: String {
        switch self {
        case .casual: "Casual"
        case .regular: "Regular"
        case .serious: "Serious"
        case .intense: "Intense"
        }
    }

    var minutesPerDay: Int {
        switch self {
        case .casual: 5
        case .regular: 10
        case .serious: 15
        case .intense: 20
        }
    }
}

enum LearningReason: String, Equatable, CaseIterable {
    case partner = "partner"
    case diaspora = "diaspora"
    case expat = "expat"
    case travel = "travel"
    case culture = "culture"
    case other = "other"

    var displayName: String {
        switch self {
        case .partner: "For a partner or family"
        case .diaspora: "Reconnecting with heritage"
        case .expat: "Living in Albania"
        case .travel: "Travel"
        case .culture: "Culture & curiosity"
        case .other: "Other reason"
        }
    }
}
