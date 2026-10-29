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

    /// `LocalizedStringResource`, so these reach the String Catalog. The
    /// persisted value is `rawValue`, which is unaffected and must stay stable.
    var displayName: LocalizedStringResource {
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

    /// XP per day that counts as meeting this goal.
    ///
    /// Derived from the minutes the learner picked rather than hand-tuned per
    /// case, so the two can never disagree. The rate comes from what the engine
    /// actually awards: exercises are worth 10-15 XP, a lesson runs 8-10 of them
    /// with a combo bonus every third correct answer, and a lesson takes about
    /// five minutes. That puts a careful learner near 12 XP per minute, so the
    /// casual goal is roughly one lesson and the intense goal roughly four.
    ///
    /// Deliberately reachable through reviews alone: a review session banks XP
    /// the same way, so a day spent only strengthening old words can still meet
    /// the goal. Making the goal lesson-only would push learners past material
    /// they have not retained, which is the opposite of what this app is for.
    var dailyXPGoal: Int { minutesPerDay * Self.xpPerMinute }

    /// XP an engaged learner earns per minute of study. See ``dailyXPGoal``.
    static let xpPerMinute = 12
}

enum LearningReason: String, Equatable, CaseIterable {
    case partner = "partner"
    case diaspora = "diaspora"
    case expat = "expat"
    case travel = "travel"
    case culture = "culture"
    case other = "other"

    /// See the note on `LearningGoal.displayName`. `rawValue` stays the
    /// persisted identity.
    var displayName: LocalizedStringResource {
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
