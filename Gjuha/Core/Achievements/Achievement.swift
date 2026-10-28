import Foundation

// MARK: - Achievement

/// A milestone the learner can reach, derived from stats they already have.
///
/// Three rules this catalogue holds itself to, because the alternative is the
/// thing this app exists to avoid:
///
/// 1. **Nothing is awarded for opening the app.** Every milestone is anchored to
///    a figure that reflects real work: lessons finished, XP earned, days kept,
///    words seen, words that survived to the scheduler's mastery interval.
/// 2. **Mastery milestones use the honest mastery figure.** `wordsMastered`
///    comes from `ReviewRepository.summary()`, the same number Profile shows,
///    which counts only words that have climbed to the documented long-term
///    interval. A "100 words mastered" badge therefore means that, and not
///    "100 words seen once".
/// 3. **Evaluation is pure.** `AchievementCatalog` is a value computation over
///    `UserStats` with no clock, no randomness and no I/O, so the same stats
///    always unlock the same set and the whole thing is testable without a
///    simulator.
struct Achievement: Identifiable, Equatable, Sendable {
    /// What a milestone is measured against. Each case names a field of
    /// `UserStats`, so adding a metric means adding a stat rather than inventing
    /// a number.
    enum Metric: String, Equatable, Sendable, CaseIterable {
        case streakDays
        case lessonsCompleted
        case totalXP
        case wordsSeen
        case wordsMastered

        func value(in stats: UserStats) -> Int {
            switch self {
            case .streakDays: stats.currentStreak
            case .lessonsCompleted: stats.lessonsCompleted
            case .totalXP: stats.totalXP
            case .wordsSeen: stats.wordsSeen
            case .wordsMastered: stats.wordsMastered
            }
        }
    }

    /// Stable identifier. Persisted in the unlock ledger, so it must never
    /// change for an existing milestone: renaming one would silently relock it
    /// for every learner who already earned it.
    let id: String
    let title: LocalizedStringResource
    let detail: LocalizedStringResource
    let symbolName: String
    let metric: Metric
    let threshold: Int

    /// Whether `stats` satisfies this milestone.
    func isUnlocked(by stats: UserStats) -> Bool {
        metric.value(in: stats) >= threshold
    }

    /// How far along `stats` is, clamped to 0...1.
    func progress(in stats: UserStats) -> Double {
        guard threshold > 0 else { return 1 }
        return min(1.0, Double(metric.value(in: stats)) / Double(threshold))
    }

    /// The learner's current figure for this milestone, capped at the threshold
    /// so a progress label reads "7/7" rather than "12/7".
    func progressValue(in stats: UserStats) -> Int {
        min(metric.value(in: stats), threshold)
    }
}

// MARK: - Catalogue

enum AchievementCatalog {
    /// Every milestone, in the order they are shown.
    ///
    /// Ordered by metric and then by threshold, which is also roughly the order a
    /// learner reaches them, so the grid reads as a ladder rather than a bag.
    static let all: [Achievement] = [
        // --- Consistency ---------------------------------------------------
        Achievement(
            id: "streak.3",
            title: "Three in a row",
            detail: "Study three days in a row.",
            symbolName: "flame",
            metric: .streakDays,
            threshold: 3
        ),
        Achievement(
            id: "streak.7",
            title: "A full week",
            detail: "Study seven days in a row.",
            symbolName: "flame.fill",
            metric: .streakDays,
            threshold: 7
        ),
        Achievement(
            id: "streak.30",
            title: "A month of Albanian",
            detail: "Study thirty days in a row.",
            symbolName: "calendar.badge.checkmark",
            metric: .streakDays,
            threshold: 30
        ),
        Achievement(
            id: "streak.100",
            title: "One hundred days",
            detail: "Study one hundred days in a row.",
            symbolName: "crown.fill",
            metric: .streakDays,
            threshold: 100
        ),

        // --- Course progress ------------------------------------------------
        Achievement(
            id: "lessons.1",
            title: "First steps",
            detail: "Finish your first lesson.",
            symbolName: "shoeprints.fill",
            metric: .lessonsCompleted,
            threshold: 1
        ),
        Achievement(
            id: "lessons.10",
            title: "Ten lessons in",
            detail: "Finish ten lessons.",
            symbolName: "book.closed.fill",
            metric: .lessonsCompleted,
            threshold: 10
        ),
        Achievement(
            id: "lessons.50",
            title: "Halfway to fluent",
            detail: "Finish fifty lessons.",
            symbolName: "books.vertical.fill",
            metric: .lessonsCompleted,
            threshold: 50
        ),

        // --- Effort ----------------------------------------------------------
        Achievement(
            id: "xp.500",
            title: "Five hundred XP",
            detail: "Earn 500 XP in total.",
            symbolName: "star.fill",
            metric: .totalXP,
            threshold: 500
        ),
        Achievement(
            id: "xp.2500",
            title: "Serious effort",
            detail: "Earn 2,500 XP in total.",
            symbolName: "star.circle.fill",
            metric: .totalXP,
            threshold: 2_500
        ),

        // --- Vocabulary breadth ---------------------------------------------
        Achievement(
            id: "seen.100",
            title: "A hundred words",
            detail: "Meet 100 different Albanian words.",
            symbolName: "text.book.closed.fill",
            metric: .wordsSeen,
            threshold: 100
        ),

        // --- Retention, the figure this app actually cares about -------------
        Achievement(
            id: "mastered.25",
            title: "Twenty-five kept",
            detail: "Carry 25 words to the long-term review interval.",
            symbolName: "brain.head.profile",
            metric: .wordsMastered,
            threshold: 25
        ),
        Achievement(
            id: "mastered.100",
            title: "One hundred kept",
            detail: "Carry 100 words to the long-term review interval.",
            symbolName: "trophy.fill",
            metric: .wordsMastered,
            threshold: 100
        )
    ]

    static func achievement(id: String) -> Achievement? {
        all.first { $0.id == id }
    }

    /// Every milestone `stats` satisfies, in catalogue order.
    static func unlocked(by stats: UserStats) -> [Achievement] {
        all.filter { $0.isUnlocked(by: stats) }
    }

    /// The closest milestone not yet reached, by proportion of the way there, so
    /// Profile can show the learner what is actually within reach rather than
    /// the next one in list order.
    ///
    /// Milestones with no progress at all are still eligible: early on nothing
    /// has progress, and returning nil there would leave the "next up" row empty
    /// exactly when it is most useful.
    static func nextUp(for stats: UserStats) -> Achievement? {
        all
            .filter { !$0.isUnlocked(by: stats) }
            .max { lhs, rhs in
                let left = lhs.progress(in: stats)
                let right = rhs.progress(in: stats)
                if left == right {
                    // Deterministic tie-break, so two equally-distant milestones
                    // do not swap places between launches.
                    return lhs.id > rhs.id
                }
                return left < right
            }
    }
}
