import Foundation
import Dependencies

// MARK: - Store

/// The unlock ledger: which milestones have been reached, and when.
///
/// Why a ledger at all, when `AchievementCatalog.unlocked(by:)` can derive the
/// set from current stats at any time: a streak can break. Derive-only would
/// mean a learner who kept a 30-day streak and then missed a day loses the "A
/// month of Albanian" badge, which would be a lie about what they did. An
/// unlock is a historical fact, so it is written down once and kept, and the
/// ledger is only ever added to, never recomputed downward.
///
/// Mirrors the other Gjuha stores: `UserDefaults`, defensive decoding, a forced
/// synchronize on the destructive path.
final class AchievementStore: @unchecked Sendable {
    static let shared = AchievementStore()

    private let defaults: UserDefaults
    private let unlockedKey = "gjuha.achievements.unlockedAt.v1"
    private let celebratedKey = "gjuha.achievements.celebrated.v1"

    /// Injectable defaults keep the store testable in isolation (a throwaway
    /// suite) without touching the app's standard defaults.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Unlock dates by achievement id. Unknown ids (a milestone removed from the
    /// catalogue in a later version) are kept in storage but filtered out on
    /// read, so a downgrade does not destroy them.
    var unlockedAt: [String: Date] {
        guard let data = defaults.data(forKey: unlockedKey), !data.isEmpty,
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return decoded
    }

    var unlockedIDs: Set<String> { Set(unlockedAt.keys) }

    func unlockDate(for id: String) -> Date? { unlockedAt[id] }

    /// Records any milestone `stats` has reached that is not already in the
    /// ledger, and returns those newly recorded, in catalogue order.
    ///
    /// Idempotent: calling it twice with the same stats returns an empty array
    /// the second time. That is what keeps a celebration from firing again every
    /// time Home reappears.
    @discardableResult
    func recordUnlocks(for stats: UserStats, now: Date = Date()) -> [Achievement] {
        var ledger = unlockedAt
        var newlyUnlocked: [Achievement] = []

        for achievement in AchievementCatalog.unlocked(by: stats) where ledger[achievement.id] == nil {
            ledger[achievement.id] = now
            newlyUnlocked.append(achievement)
        }

        guard !newlyUnlocked.isEmpty else { return [] }
        write(ledger)
        return newlyUnlocked
    }

    /// Milestones that are unlocked but have not yet been shown to the learner.
    ///
    /// Tracked separately from the unlock ledger, because "earned" and "has been
    /// shown the celebration" are different facts with different lifetimes: the
    /// unlock is durable the instant it happens, while the celebration is owed
    /// until a screen has actually presented it.
    ///
    /// Nothing reads this yet. The completion screen is told which badges a
    /// session earned directly, and marks exactly those as shown. This exists so
    /// that a surface which asks "what did I earn while I was away" has a correct
    /// answer available, and so the ledger is not the only record of what the
    /// learner has actually seen. It is covered by tests rather than left as an
    /// untested promise.
    var uncelebrated: [Achievement] {
        let celebrated = Set(defaults.stringArray(forKey: celebratedKey) ?? [])
        return unlockedIDs
            .subtracting(celebrated)
            .compactMap(AchievementCatalog.achievement(id:))
            .sorted { lhs, rhs in
                let order = AchievementCatalog.all.map(\.id)
                return (order.firstIndex(of: lhs.id) ?? 0) < (order.firstIndex(of: rhs.id) ?? 0)
            }
    }

    func markCelebrated(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        var celebrated = Set(defaults.stringArray(forKey: celebratedKey) ?? [])
        celebrated.formUnion(ids)
        defaults.set(Array(celebrated).sorted(), forKey: celebratedKey)
    }

    /// Clears the ledger. Called by "reset learning data": the stats it was
    /// derived from are gone, so keeping the badges would present milestones the
    /// learner's visible progress no longer supports.
    func reset() {
        defaults.removeObject(forKey: unlockedKey)
        defaults.removeObject(forKey: celebratedKey)
        defaults.synchronize()
    }

    private func write(_ ledger: [String: Date]) {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        defaults.set(data, forKey: unlockedKey)
    }
}

// MARK: - Client

/// Feature-facing view of the achievement system.
protocol AchievementsClient: Sendable {
    /// Records anything `stats` has newly earned and returns it, for a
    /// celebration. Empty when nothing changed.
    func recordUnlocks(for stats: UserStats) async -> [Achievement]
    /// Every milestone with its unlock date, for the Profile grid.
    func unlockDates() async -> [String: Date]
    /// Marks milestones as having been shown, so they are not celebrated twice.
    func markCelebrated(_ ids: [String]) async
}

private enum AchievementsClientKey: DependencyKey {
    static let liveValue: any AchievementsClient = LiveAchievementsClient()
    static let testValue: any AchievementsClient = NoopAchievementsClient()
    static let previewValue: any AchievementsClient = NoopAchievementsClient()
}

extension DependencyValues {
    var achievements: any AchievementsClient {
        get { self[AchievementsClientKey.self] }
        set { self[AchievementsClientKey.self] = newValue }
    }
}

struct LiveAchievementsClient: AchievementsClient {
    func recordUnlocks(for stats: UserStats) async -> [Achievement] {
        AchievementStore.shared.recordUnlocks(for: stats)
    }

    func unlockDates() async -> [String: Date] {
        AchievementStore.shared.unlockedAt
    }

    func markCelebrated(_ ids: [String]) async {
        AchievementStore.shared.markCelebrated(ids)
    }
}

/// Used in tests and previews, so neither writes to the real defaults.
struct NoopAchievementsClient: AchievementsClient {
    func recordUnlocks(for stats: UserStats) async -> [Achievement] { [] }
    func unlockDates() async -> [String: Date] { [:] }
    func markCelebrated(_ ids: [String]) async {}
}
