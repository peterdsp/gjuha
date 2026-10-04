import Foundation
import UserNotifications
import Dependencies

// MARK: - Settings

/// A daily study reminder, opt in and off by default. Time is stored as an hour and
/// minute in the device's local time; the system fires the notification at that wall
/// clock time each day, so it follows the user across time zones.
struct ReminderSettings: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var hour: Int
    var minute: Int

    static let `default` = ReminderSettings(isEnabled: false, hour: 19, minute: 0)

    /// The notification's daily trigger components. Only hour and minute are set, so
    /// `UNCalendarNotificationTrigger(repeats: true)` fires once every day at that
    /// local time.
    var triggerComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }

    /// A localized, 24h-safe label like "19:00" for display.
    var timeLabel: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

/// UserDefaults persistence for the reminder settings, mirroring the other stores.
final class ReminderSettingsStore: @unchecked Sendable {
    static let shared = ReminderSettingsStore()

    private let defaults: UserDefaults
    private let key = "gjuha.reminderSettings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ReminderSettings {
        guard let data = defaults.data(forKey: key), !data.isEmpty,
              let decoded = try? JSONDecoder().decode(ReminderSettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    func save(_ settings: ReminderSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}

// MARK: - Authorization

/// A small, app facing view of the system notification authorization state, so the
/// feature layer does not depend on UserNotifications types directly.
enum ReminderAuthorization: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

// MARK: - Client

protocol ReminderClient: Sendable {
    /// The current authorization without prompting.
    func currentAuthorization() async -> ReminderAuthorization
    /// Prompts for authorization if not yet determined, and returns the result.
    func requestAuthorization() async -> ReminderAuthorization
    /// Schedules (or replaces) the single daily reminder at the given local time.
    func schedule(hour: Int, minute: Int) async
    /// Cancels the daily reminder if present.
    func cancel() async
}

private enum ReminderClientKey: DependencyKey {
    static let liveValue: any ReminderClient = LiveReminderClient()
    static let testValue: any ReminderClient = MockReminderClient()
    static let previewValue: any ReminderClient = MockReminderClient()
}

extension DependencyValues {
    var reminderClient: any ReminderClient {
        get { self[ReminderClientKey.self] }
        set { self[ReminderClientKey.self] = newValue }
    }
}

// MARK: - Live

final class LiveReminderClient: ReminderClient, @unchecked Sendable {
    private let identifier = "gjuha.dailyReminder"
    private let center = UNUserNotificationCenter.current()

    private func map(_ status: UNAuthorizationStatus) -> ReminderAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized, .provisional, .ephemeral: return .authorized
        @unknown default: return .denied
        }
    }

    func currentAuthorization() async -> ReminderAuthorization {
        let settings = await center.notificationSettings()
        return map(settings.authorizationStatus)
    }

    func requestAuthorization() async -> ReminderAuthorization {
        let current = await currentAuthorization()
        guard current == .notDetermined else { return current }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        return granted ? .authorized : .denied
    }

    func schedule(hour: Int, minute: Int) async {
        // Replace any existing reminder so changing the time never stacks duplicates.
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Koha për shqip"
        content.body = "A few minutes today keeps your Albanian, and your streak, alive."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: hour, minute: minute),
            repeats: true
        )
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancel() async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

// MARK: - Mock

final class MockReminderClient: ReminderClient, @unchecked Sendable {
    func currentAuthorization() async -> ReminderAuthorization { .authorized }
    func requestAuthorization() async -> ReminderAuthorization { .authorized }
    func schedule(hour: Int, minute: Int) async {}
    func cancel() async {}
}
