import ComposableArchitecture
import Foundation

@Reducer
struct ProfileFeature {
    @ObservableState
    struct State: Equatable {
        var stats: UserStats = .empty
        var selectedGoal: LearningGoal = .casual
        var isLoading: Bool = false

        /// Daily reminder settings (opt in, off by default).
        var reminder: ReminderSettings = .default
        /// Set when the user turned the reminder on but notifications are denied at
        /// the system level, so the view can explain how to enable them in Settings.
        var reminderPermissionDenied: Bool = false

        /// Whether the "reset learning data" confirmation is showing.
        var showResetConfirmation: Bool = false
    }

    enum Action {
        case onAppear
        case statsLoaded(UserStats)
        case goalLoaded(LearningGoal)
        case goalChanged(LearningGoal)
        case reminderSettingsLoaded(ReminderSettings)
        case reminderToggled(Bool)
        case reminderAuthorizationResponse(ReminderAuthorization)
        case reminderTimeChanged(hour: Int, minute: Int)
        case reminderPermissionAlertDismissed
        case resetDataTapped
        case resetConfirmationDismissed
        case resetConfirmed
        /// Emitted after a reset finishes, so the parent can refresh other tabs
        /// (the Home path and unlock state) that cache progress separately.
        case resetCompleted
    }

    @Dependency(\.progressRepository) var progressRepository
    @Dependency(\.reminderClient) var reminderClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                state.reminder = ReminderSettingsStore.shared.load()
                return .run { send in
                    let stats = await progressRepository.fetchUserStats()
                    await send(.statsLoaded(stats))
                    let goal = await progressRepository.fetchLearningGoal()
                    await send(.goalLoaded(goal))
                    await send(.reminderSettingsLoaded(ReminderSettingsStore.shared.load()))
                }
            case .statsLoaded(let stats):
                state.stats = stats
                state.isLoading = false
                return .none
            case .goalLoaded(let goal):
                state.selectedGoal = goal
                return .none
            case .goalChanged(let goal):
                state.selectedGoal = goal
                return .run { _ in
                    await progressRepository.saveLearningGoal(goal)
                }

            case .reminderSettingsLoaded(let settings):
                state.reminder = settings
                return .none

            case .reminderToggled(let isOn):
                if isOn {
                    // Turning on: confirm authorization first, then schedule.
                    return .run { send in
                        let auth = await reminderClient.requestAuthorization()
                        await send(.reminderAuthorizationResponse(auth))
                    }
                } else {
                    state.reminder.isEnabled = false
                    let settings = state.reminder
                    return .run { _ in
                        ReminderSettingsStore.shared.save(settings)
                        await reminderClient.cancel()
                    }
                }

            case .reminderAuthorizationResponse(let auth):
                guard auth == .authorized else {
                    // Denied: keep the toggle off and surface guidance.
                    state.reminder.isEnabled = false
                    state.reminderPermissionDenied = true
                    let settings = state.reminder
                    return .run { _ in ReminderSettingsStore.shared.save(settings) }
                }
                state.reminder.isEnabled = true
                let settings = state.reminder
                return .run { _ in
                    ReminderSettingsStore.shared.save(settings)
                    await reminderClient.schedule(hour: settings.hour, minute: settings.minute)
                }

            case .reminderTimeChanged(let hour, let minute):
                state.reminder.hour = hour
                state.reminder.minute = minute
                let settings = state.reminder
                return .run { _ in
                    ReminderSettingsStore.shared.save(settings)
                    if settings.isEnabled {
                        await reminderClient.schedule(hour: settings.hour, minute: settings.minute)
                    }
                }

            case .reminderPermissionAlertDismissed:
                state.reminderPermissionDenied = false
                return .none

            case .resetDataTapped:
                state.showResetConfirmation = true
                return .none

            case .resetConfirmationDismissed:
                state.showResetConfirmation = false
                return .none

            case .resetConfirmed:
                state.showResetConfirmation = false
                return .run { send in
                    await progressRepository.resetLearningData()
                    let stats = await progressRepository.fetchUserStats()
                    await send(.statsLoaded(stats))
                    await send(.resetCompleted)
                }

            case .resetCompleted:
                // Observed by the parent to refresh other tabs; nothing to do here.
                return .none
            }
        }
    }
}
