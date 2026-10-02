import Foundation

/// UserDefaults backed persistence for spaced repetition state, mirroring
/// `ProgressStore`. One JSON blob holds the dictionary of word id to review state.
///
/// Decoding is defensive: missing, empty, or corrupt data yields an empty schedule
/// rather than crashing, so an upgrade from a build that never wrote this key, or a
/// partially written blob, degrades to "no reviews yet" instead of data loss on the
/// rest of the app.
final class ReviewStore: @unchecked Sendable {
    static let shared = ReviewStore()

    private let defaults: UserDefaults
    private let key = "gjuha.reviewSchedule.v1"

    /// Injectable defaults keep the store testable in isolation (a throwaway suite)
    /// without touching the app's standard defaults.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// All review items, keyed by stable word id.
    func load() -> [String: ReviewItemState] {
        guard let data = defaults.data(forKey: key), !data.isEmpty else { return [:] }
        guard let decoded = try? JSONDecoder().decode([String: ReviewItemState].self, from: data) else {
            return [:]
        }
        return decoded
    }

    func save(_ items: [String: ReviewItemState]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }

    /// Inserts items for words not already scheduled. Existing schedules are left
    /// untouched, so re-completing a lesson never resets progress on its words.
    func insertNewItems(_ newItems: [ReviewItemState]) {
        var items = load()
        var changed = false
        for item in newItems where items[item.wordId] == nil {
            items[item.wordId] = item
            changed = true
        }
        if changed { save(items) }
    }

    func upsert(_ item: ReviewItemState) {
        var items = load()
        items[item.wordId] = item
        save(items)
    }
}
