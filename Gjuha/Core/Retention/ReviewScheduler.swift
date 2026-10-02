import Foundation

// MARK: - Review grade

/// The learner's recall outcome for a single reviewed word.
///
/// These map from the exercise engine's `AnswerGrade` at the call site:
/// `correct -> good`, `nearMiss -> hard`, `incorrect -> again`. `easy` is modeled
/// so a future "I knew it instantly" affordance can use it, but the current review
/// UI never fabricates it from timing or combo.
enum ReviewGrade: String, Codable, Equatable, Sendable, CaseIterable {
    case again   // failed to recall; a lapse
    case hard    // recalled, but with difficulty (a near miss)
    case good    // recalled correctly
    case easy    // recalled effortlessly
}

// MARK: - Review item state

/// Durable scheduling state for one vocabulary word, keyed by the stable word id
/// (`wNNN`). Day granularity: intervals and due dates are whole days in the
/// learner's calendar, which matches a once per day study cadence.
struct ReviewItemState: Codable, Equatable, Sendable {
    let wordId: String
    /// Current spacing interval in days. 0 means the item is due again immediately
    /// (a new or lapsed item that needs to be seen in the current day's session).
    var intervalDays: Int
    /// SM-2 ease factor. Higher means intervals grow faster. Clamped to [1.3, 3.0].
    var ease: Double
    /// Count of consecutive non-`again` reviews. Drives the early interval ramp.
    var reps: Int
    /// Number of times the word has lapsed (`again`) since it was introduced.
    var lapses: Int
    /// Start of day on which the item becomes due.
    var dueDate: Date
    /// When the item was last reviewed, or nil if it has only been introduced.
    var lastReviewed: Date?
    /// When the word first entered the schedule.
    var introducedAt: Date
}

/// One generated review question paired with the stable word id it exercises, so
/// the review session can record the outcome against the right schedule entry
/// (`Exercise.wordId` is a UUID and is not used as the schedule key).
struct ReviewExercise: Equatable, Sendable, Identifiable {
    let wordId: String
    let exercise: Exercise
    var id: UUID { exercise.id }
}

// MARK: - Scheduler

/// A deterministic spaced repetition scheduler derived from SM-2 (Wozniak, 1987).
///
/// Why SM-2 and not FSRS: SM-2 is simple, well understood, and fully deterministic,
/// so it is unit testable with a fixed clock and needs no per learner training data.
/// FSRS gives better intervals but fits a machine learned forgetting curve over a
/// large personal review history, which is non deterministic and premature at
/// launch. The scheduler is kept behind this value type so FSRS can replace it later
/// without touching the feature layer.
///
/// Algorithm (day granularity, all dates reduced to start of day):
/// - New word (just learned in a lesson): treated as one successful rep, first
///   spaced review one day later.
/// - `good`: interval goes 1 day, then 6 days, then previous interval times ease.
/// - `easy`: a longer step than `good` and a small ease increase.
/// - `hard`: a short step (previous interval times 1.2) and a small ease decrease.
/// - `again`: a lapse. Ease decreases, the item is due again the same day, and the
///   rep streak resets so the word has to climb back up.
/// Intervals are capped so a word always returns within a year.
struct ReviewScheduler: Sendable {
    /// Default SM-2 ease.
    static let defaultEase: Double = 2.5
    static let minEase: Double = 1.3
    static let maxEase: Double = 3.0
    /// Longest spacing we allow, so even easy words resurface within a year.
    static let maxIntervalDays: Int = 365
    /// A word is considered "mastered" once it survives to this interval. Twenty one
    /// days is a conventional long term retention threshold (roughly three good
    /// reviews past the 6 day step) and is documented so the Profile stat is honest.
    static let masteryIntervalDays: Int = 21

    var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    private func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func addDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: startOfDay(date)) ?? startOfDay(date)
    }

    private func clampEase(_ value: Double) -> Double {
        min(Self.maxEase, max(Self.minEase, value))
    }

    /// State for a word that has just been learned in a lesson. The lesson counts as
    /// the first successful exposure, so the first spaced review is one day later.
    func newItem(wordId: String, now: Date) -> ReviewItemState {
        ReviewItemState(
            wordId: wordId,
            intervalDays: 1,
            ease: Self.defaultEase,
            reps: 1,
            lapses: 0,
            dueDate: addDays(1, to: now),
            lastReviewed: nil,
            introducedAt: startOfDay(now)
        )
    }

    /// Applies a review outcome and returns the updated state.
    func apply(_ grade: ReviewGrade, to item: ReviewItemState, now: Date) -> ReviewItemState {
        var updated = item
        updated.lastReviewed = now

        switch grade {
        case .again:
            updated.lapses += 1
            updated.reps = 0
            updated.ease = clampEase(item.ease - 0.20)
            updated.intervalDays = 0
            updated.dueDate = startOfDay(now) // see it again today

        case .hard:
            updated.ease = clampEase(item.ease - 0.15)
            let base = max(1, item.intervalDays)
            updated.intervalDays = min(Self.maxIntervalDays, Int((Double(base) * 1.2).rounded()))
            updated.reps = item.reps + 1
            updated.dueDate = addDays(updated.intervalDays, to: now)

        case .good:
            let interval: Int
            switch item.reps {
            case 0: interval = 1
            case 1: interval = 6
            default: interval = Int((Double(item.intervalDays) * item.ease).rounded())
            }
            updated.intervalDays = min(Self.maxIntervalDays, max(1, interval))
            updated.reps = item.reps + 1
            updated.dueDate = addDays(updated.intervalDays, to: now)

        case .easy:
            updated.ease = clampEase(item.ease + 0.15)
            let interval: Int
            switch item.reps {
            case 0: interval = 4
            case 1: interval = 8
            default: interval = Int((Double(item.intervalDays) * updated.ease * 1.3).rounded())
            }
            updated.intervalDays = min(Self.maxIntervalDays, max(1, interval))
            updated.reps = item.reps + 1
            updated.dueDate = addDays(updated.intervalDays, to: now)
        }

        return updated
    }

    /// Whether the item is due on or before the given day.
    func isDue(_ item: ReviewItemState, now: Date) -> Bool {
        startOfDay(item.dueDate) <= startOfDay(now)
    }

    /// Whether the item has reached the documented mastery interval.
    func isMastered(_ item: ReviewItemState) -> Bool {
        item.intervalDays >= Self.masteryIntervalDays
    }

    /// Due items, struggling words first, in a deterministic order.
    ///
    /// Sort: earliest due first, then more lapses first (shakier words get priority),
    /// then stable by word id so the order never depends on dictionary iteration.
    func dueItems(from items: [ReviewItemState], now: Date, limit: Int? = nil) -> [ReviewItemState] {
        let due = items
            .filter { isDue($0, now: now) }
            .sorted { lhs, rhs in
                let l = startOfDay(lhs.dueDate), r = startOfDay(rhs.dueDate)
                if l != r { return l < r }
                if lhs.lapses != rhs.lapses { return lhs.lapses > rhs.lapses }
                return lhs.wordId < rhs.wordId
            }
        if let limit, limit >= 0 { return Array(due.prefix(limit)) }
        return due
    }
}
