import Testing
import Foundation
import SwiftUI
import UIKit
@testable import Gjuha

// Tests for the design system and the retention surfaces added in this pass:
// measured colour contrast, the spacing grid, the daily XP goal, the achievement
// catalogue and its ledger, and the two stored payloads that gained fields after
// 1.0 was already installable.
//
// Like the rest of this target these are pure logic and resource tests resolved
// through the app host, because the test bundle cannot link
// ComposableArchitecture on this toolchain (see the note in project.yml).

// MARK: - Contrast

/// Asserts the palette's legibility against the colours the app actually
/// resolves at runtime, rather than against the numbers in
/// `Scripts/gen_colors.py`.
///
/// Both ends matter. The script refuses to *write* a set that measures below the
/// floor, and this suite refuses to *ship* one: between them sits the asset
/// catalog, which someone can edit in Xcode without ever running the script. The
/// two agreeing is the only reason either claim is worth anything.
struct GjuhaContrastTests {

    /// WCAG 2.1 normal-text minimum. Everything checked here is text or an icon
    /// that has to stay legible, so none of it takes the 3:1 large-text
    /// relaxation.
    static let floor = 4.5

    /// Every appearance the palette ships, as the trait collection that selects
    /// it. Increased contrast is included because the whole point of adding
    /// those variants was that the setting previously did nothing.
    ///
    /// Built from the composing initialisers rather than the trait-mutation
    /// closure, which carries main-actor isolation that a nonisolated stored
    /// property cannot satisfy.
    static var appearances: [(name: String, traits: UITraitCollection)] {
        func traits(_ style: UIUserInterfaceStyle, _ contrast: UIAccessibilityContrast) -> UITraitCollection {
            UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceStyle: style),
                UITraitCollection(accessibilityContrast: contrast)
            ])
        }
        return [
            ("light", traits(.light, .normal)),
            ("dark", traits(.dark, .normal)),
            ("light+HC", traits(.light, .high)),
            ("dark+HC", traits(.dark, .high))
        ]
    }

    /// Relative luminance per WCAG 2.1.
    static func luminance(_ color: UIColor, _ traits: UITraitCollection) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func linear(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    static func ratio(
        _ foreground: Color,
        on background: Color,
        in traits: UITraitCollection
    ) -> Double {
        let a = luminance(UIColor(foreground), traits)
        let b = luminance(UIColor(background), traits)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// Every on-surface token against the surfaces it is drawn on.
    @Test
    func textTokensClearTheFloorOnEverySurface() {
        let palette = Color.gjuha
        let pairs: [(String, Color, Color)] = [
            ("textPrimary/surface", palette.textPrimary, palette.surface),
            ("textSecondary/surface", palette.textSecondary, palette.surface),
            ("textTertiary/surface", palette.textTertiary, palette.surface),
            ("textPrimary/background", palette.textPrimary, palette.background),
            ("textSecondary/background", palette.textSecondary, palette.background),
            ("textTertiary/background", palette.textTertiary, palette.background),
            ("textPrimary/surfaceSecondary", palette.textPrimary, palette.surfaceSecondary),
            ("textSecondary/surfaceSecondary", palette.textSecondary, palette.surfaceSecondary)
        ]

        for (label, foreground, background) in pairs {
            for appearance in Self.appearances {
                let measured = Self.ratio(foreground, on: background, in: appearance.traits)
                #expect(
                    measured >= Self.floor,
                    "\(label) measured \(measured) in \(appearance.name), floor is \(Self.floor)"
                )
            }
        }
    }

    /// The `*Strong` tokens exist so a brand or state colour can be used as text.
    /// Their unsuffixed fills measure as low as 1.76:1 here, which is what the
    /// app was doing before.
    @Test
    func brandAndStateTokensAreLegibleAsTextOnSurfaces() {
        let palette = Color.gjuha
        let foregrounds: [(String, Color)] = [
            ("accentStrong", palette.accentStrong),
            ("successStrong", palette.successStrong),
            ("errorStrong", palette.errorStrong),
            ("warningStrong", palette.warningStrong),
            ("streakStrong", palette.streakStrong),
            ("xpStrong", palette.xpStrong)
        ]

        for (label, foreground) in foregrounds {
            for background in [("surface", palette.surface), ("background", palette.background)] {
                for appearance in Self.appearances {
                    let measured = Self.ratio(foreground, on: background.1, in: appearance.traits)
                    #expect(
                        measured >= Self.floor,
                        "\(label) on \(background.0) measured \(measured) in \(appearance.name)"
                    )
                }
            }
        }
    }

    /// A fill carries a documented foreground, and the pairing has to hold in
    /// every appearance. `warning` and `xp` stay bright and take `onWarning`;
    /// the rest carry `onAccent`.
    @Test
    func everyFillIsLegibleWithItsDocumentedForeground() {
        let palette = Color.gjuha
        let pairs: [(String, Color, Color)] = [
            ("onAccent/accent", palette.onAccent, palette.accent),
            ("onAccent/streak", palette.onAccent, palette.streak),
            ("onAccent/success", palette.onAccent, palette.success),
            ("onAccent/error", palette.onAccent, palette.error),
            ("onWarning/warning", palette.onWarning, palette.warning),
            ("onWarning/xp", palette.onWarning, palette.xp)
        ]

        for (label, foreground, fill) in pairs {
            for appearance in Self.appearances {
                let measured = Self.ratio(foreground, on: fill, in: appearance.traits)
                #expect(
                    measured >= Self.floor,
                    "\(label) measured \(measured) in \(appearance.name)"
                )
            }
        }
    }

    /// The overlay tints replaced hardcoded `Color.white.opacity(…)`, whose whole
    /// problem was being invisible on a light surface. A token that resolves to
    /// nearly the surface it sits on would have the same bug, so each one has to
    /// actually differ from that surface.
    @Test
    func overlayTintsAreVisibleAgainstTheirSurface() {
        let palette = Color.gjuha
        let overlays: [(String, Color)] = [
            ("hairline", palette.hairline),
            ("track", palette.track),
            ("chipFill", palette.chipFill)
        ]

        for (label, overlay) in overlays {
            for appearance in Self.appearances {
                // Composite the overlay over the surface, which is what the
                // renderer does, then compare the result with the bare surface.
                let composited = Self.composite(overlay, over: palette.surface, in: appearance.traits)
                let surface = Self.luminance(UIColor(palette.surface), appearance.traits)
                #expect(
                    abs(composited - surface) > 0.004,
                    "\(label) is indistinguishable from surface in \(appearance.name)"
                )
            }
        }
    }

    /// Luminance of `overlay` composited over `base` using source-over alpha,
    /// which is what a `.fill()` on top of a background produces.
    static func composite(
        _ overlay: Color,
        over base: Color,
        in traits: UITraitCollection
    ) -> Double {
        var oR: CGFloat = 0, oG: CGFloat = 0, oB: CGFloat = 0, oA: CGFloat = 0
        UIColor(overlay).resolvedColor(with: traits).getRed(&oR, green: &oG, blue: &oB, alpha: &oA)
        var bR: CGFloat = 0, bG: CGFloat = 0, bB: CGFloat = 0, bA: CGFloat = 0
        UIColor(base).resolvedColor(with: traits).getRed(&bR, green: &bG, blue: &bB, alpha: &bA)

        func linear(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        func blend(_ over: CGFloat, _ under: CGFloat) -> Double {
            linear(over) * Double(oA) + linear(under) * (1 - Double(oA))
        }
        return 0.2126 * blend(oR, bR) + 0.7152 * blend(oG, bG) + 0.0722 * blend(oB, bB)
    }

    /// Named colours resolve from the asset catalog rather than falling back to
    /// an opaque default, which is how a typo in a token name would present: the
    /// app still builds and the colour is silently wrong.
    @Test
    func newTokensResolveFromTheAssetCatalog() {
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let palette = Color.gjuha

        // Each of these is defined with a different value per appearance, so a
        // token that failed to resolve would come back identical in both and is
        // caught here.
        for (label, color) in [
            ("accentStrong", palette.accentStrong),
            ("successStrong", palette.successStrong),
            ("streakStrong", palette.streakStrong),
            ("xpStrong", palette.xpStrong),
            ("warningStrong", palette.warningStrong),
            ("errorStrong", palette.errorStrong),
            ("hairline", palette.hairline),
            ("glassTint", palette.glassTint),
            ("track", palette.track),
            ("chipFill", palette.chipFill),
            ("controlFill", palette.controlFill)
        ] {
            let resolvedLight = UIColor(color).resolvedColor(with: light)
            let resolvedDark = UIColor(color).resolvedColor(with: dark)
            #expect(resolvedLight != resolvedDark, "\(label) does not vary by appearance")
        }
    }
}

// MARK: - Spacing

struct GjuhaSpacingTests {

    @Test
    func everyStepIsOnTheFourPointGrid() {
        for step in CGFloat.gjuha.allSteps {
            #expect(step.truncatingRemainder(dividingBy: 4) == 0, "\(step) is off the 4pt grid")
            #expect(step > 0)
        }
    }

    @Test
    func stepsIncreaseMonotonically() {
        let steps = CGFloat.gjuha.allSteps
        #expect(steps == steps.sorted())
        #expect(Set(steps).count == steps.count, "a step is duplicated")
    }

    @Test
    func minimumHitTargetMatchesApplesFloor() {
        #expect(GjuhaSpacing.minimumHitTarget == 44)
    }
}

// MARK: - Daily goal

struct DailyGoalTests {

    /// Storage keys, written as literals on purpose. `ProgressStore.Keys` is
    /// private, and these strings are a persistence contract: renaming one
    /// silently zeroes a learner's progress on update, so having a test that
    /// fails when they change is the point rather than an inconvenience.
    private enum Keys {
        static let xpToday = "gjuha.xpToday"
        static let xpTodayDate = "gjuha.xpTodayDate"
        static let totalXP = "gjuha.totalXP"
    }

    @Test
    func goalIsDerivedFromTheChosenMinutes() {
        for goal in LearningGoal.allCases {
            #expect(goal.dailyXPGoal == goal.minutesPerDay * LearningGoal.xpPerMinute)
            #expect(goal.dailyXPGoal > 0)
        }
    }

    @Test
    func aMoreAmbitiousGoalAsksForMoreXP() {
        #expect(LearningGoal.casual.dailyXPGoal < LearningGoal.regular.dailyXPGoal)
        #expect(LearningGoal.regular.dailyXPGoal < LearningGoal.serious.dailyXPGoal)
        #expect(LearningGoal.serious.dailyXPGoal < LearningGoal.intense.dailyXPGoal)
    }

    @Test
    func lessonXPCountsTowardTodayAndTheLifetimeTotal() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ProgressStore(defaults: defaults)

        store.markLessonCompleted(seedId: "u1-l1", xpEarned: 40)

        #expect(store.xpEarnedToday == 40)
        #expect(store.totalXP == 40)
    }

    /// A review banks XP without completing a lesson, and that XP has to count
    /// toward the daily goal too: the goal is deliberately reachable by reviewing
    /// alone, so a learner is never pushed past material they have not retained
    /// just to keep a ring full.
    @Test
    func reviewXPCountsTowardToday() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ProgressStore(defaults: defaults)

        store.addXP(25)

        #expect(store.xpEarnedToday == 25)
        #expect(store.totalXP == 25)
    }

    @Test
    func todaysXPAccumulatesWithinTheSameDay() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ProgressStore(defaults: defaults)

        store.markLessonCompleted(seedId: "u1-l1", xpEarned: 30)
        store.addXP(15)

        #expect(store.xpEarnedToday == 45)
    }

    /// The rollover is a read-time comparison, not a scheduled reset, so it
    /// happens correctly even though the app was never running at midnight.
    @Test
    func yesterdaysXPReadsAsZeroToday() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ProgressStore(defaults: defaults)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        defaults.set(120, forKey: Keys.xpToday)
        defaults.set(Calendar.current.startOfDay(for: yesterday), forKey: Keys.xpTodayDate)

        #expect(store.xpEarnedToday == 0)
    }

    /// And the lifetime total is untouched by the rollover: only today's figure
    /// resets.
    @Test
    func rolloverDoesNotTouchTheLifetimeTotal() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ProgressStore(defaults: defaults)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        defaults.set(120, forKey: Keys.xpToday)
        defaults.set(Calendar.current.startOfDay(for: yesterday), forKey: Keys.xpTodayDate)
        defaults.set(900, forKey: Keys.totalXP)

        store.addXP(10)

        #expect(store.xpEarnedToday == 10, "today starts from zero after a rollover")
        #expect(store.totalXP == 910, "the lifetime total keeps accumulating")
    }

    @Test
    func resettingLearningDataClearsTodaysXP() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ProgressStore(defaults: defaults)

        store.markLessonCompleted(seedId: "u1-l1", xpEarned: 60)
        store.resetLearningProgress()

        #expect(store.xpEarnedToday == 0)
        #expect(store.totalXP == 0)
    }

    @Test
    func goalProgressIsClampedButTheRawFigureIsNot() {
        let stats = UserStats(
            currentStreak: 1,
            totalXP: 400,
            wordsSeen: 10,
            lessonsCompleted: 2,
            xpToday: 300,
            dailyGoalXP: 120
        )

        #expect(stats.dailyGoalProgress == 1.0, "a ring cannot overfill")
        #expect(stats.xpToday == 300, "but the learner still sees what they did")
        #expect(stats.hasMetDailyGoal)
    }

    @Test
    func goalProgressIsProportionalBelowTheGoal() {
        let stats = UserStats(
            currentStreak: 1,
            totalXP: 60,
            wordsSeen: 10,
            lessonsCompleted: 1,
            xpToday: 60,
            dailyGoalXP: 120
        )

        #expect(stats.dailyGoalProgress == 0.5)
        #expect(!stats.hasMetDailyGoal)
    }

    /// A zero goal must not divide by zero or report itself as met with no work
    /// done. Reachable through a decoded payload that predates the field.
    @Test
    func aZeroGoalIsNeitherMetNorDividedBy() {
        let stats = UserStats(
            currentStreak: 0,
            totalXP: 0,
            wordsSeen: 0,
            lessonsCompleted: 0,
            xpToday: 0,
            dailyGoalXP: 0
        )

        #expect(stats.dailyGoalProgress == 0)
        #expect(!stats.hasMetDailyGoal)
    }
}

// MARK: - Achievement catalogue

struct AchievementCatalogTests {

    private func stats(
        streak: Int = 0,
        lessons: Int = 0,
        xp: Int = 0,
        seen: Int = 0,
        mastered: Int = 0
    ) -> UserStats {
        UserStats(
            currentStreak: streak,
            totalXP: xp,
            wordsSeen: seen,
            lessonsCompleted: lessons,
            wordsPracticed: mastered,
            wordsMastered: mastered
        )
    }

    /// Ids are persisted in the unlock ledger, so a duplicate would make two
    /// milestones share one unlock and a rename would relock an earned one.
    @Test
    func idsAreUniqueAndStable() {
        let ids = AchievementCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate achievement id")
        #expect(ids.allSatisfy { !$0.isEmpty })
    }

    @Test
    func everyThresholdIsPositive() {
        for achievement in AchievementCatalog.all {
            #expect(achievement.threshold > 0, "\(achievement.id) has a non-positive threshold")
        }
    }

    @Test
    func nothingIsUnlockedByAFreshAccount() {
        #expect(AchievementCatalog.unlocked(by: .empty).isEmpty)
    }

    @Test
    func evaluationIsDeterministic() {
        let sample = stats(streak: 9, lessons: 12, xp: 900, seen: 140, mastered: 30)
        let first = AchievementCatalog.unlocked(by: sample).map(\.id)
        let second = AchievementCatalog.unlocked(by: sample).map(\.id)
        #expect(first == second)
    }

    @Test
    func aMilestoneUnlocksExactlyAtItsThreshold() {
        let sevenDays = stats(streak: 7)
        let sixDays = stats(streak: 6)

        let weekly = AchievementCatalog.achievement(id: "streak.7")
        #expect(weekly?.isUnlocked(by: sevenDays) == true)
        #expect(weekly?.isUnlocked(by: sixDays) == false)
    }

    @Test
    func betterStatsNeverUnlockFewerMilestones() {
        let modest = stats(streak: 3, lessons: 1, xp: 500, seen: 100, mastered: 25)
        let better = stats(streak: 30, lessons: 50, xp: 2_500, seen: 400, mastered: 100)

        let modestIDs = Set(AchievementCatalog.unlocked(by: modest).map(\.id))
        let betterIDs = Set(AchievementCatalog.unlocked(by: better).map(\.id))

        #expect(modestIDs.isSubset(of: betterIDs))
        #expect(betterIDs.count > modestIDs.count)
    }

    /// Mastery milestones read the honest mastery figure, not words seen. A
    /// learner who has met 400 words but mastered none must not be told they
    /// mastered 100.
    @Test
    func masteryMilestonesIgnoreMereExposure() {
        let seenButNotKept = stats(seen: 4_000, mastered: 0)
        let unlocked = Set(AchievementCatalog.unlocked(by: seenButNotKept).map(\.id))

        #expect(!unlocked.contains("mastered.25"))
        #expect(!unlocked.contains("mastered.100"))
        #expect(unlocked.contains("seen.100"), "breadth is still its own milestone")
    }

    @Test
    func progressIsClampedToOne() {
        let far = stats(streak: 10_000)
        for achievement in AchievementCatalog.all {
            #expect(achievement.progress(in: far) <= 1.0)
            #expect(achievement.progress(in: far) >= 0.0)
            #expect(achievement.progressValue(in: far) <= achievement.threshold)
        }
    }

    @Test
    func nextUpPicksTheClosestUnreachedMilestone() {
        // 6 of 7 streak days is 86% of the way to "A full week", further along
        // than any other unreached milestone here.
        let almostAWeek = stats(streak: 6, lessons: 1, xp: 10, seen: 5, mastered: 0)
        #expect(AchievementCatalog.nextUp(for: almostAWeek)?.id == "streak.7")
    }

    @Test
    func nextUpIsNilOnlyWhenEverythingIsUnlocked() {
        let everything = stats(streak: 500, lessons: 500, xp: 500_000, seen: 5_000, mastered: 5_000)
        #expect(AchievementCatalog.unlocked(by: everything).count == AchievementCatalog.all.count)
        #expect(AchievementCatalog.nextUp(for: everything) == nil)
    }

    /// Early on nothing has progress, and that is exactly when the "next up" row
    /// is most useful, so it must still return something.
    @Test
    func nextUpIsOfferedToABrandNewLearner() {
        #expect(AchievementCatalog.nextUp(for: .empty) != nil)
    }
}

// MARK: - Achievement ledger

struct AchievementStoreTests {

    private func stats(streak: Int = 0, lessons: Int = 0) -> UserStats {
        UserStats(currentStreak: streak, totalXP: 0, wordsSeen: 0, lessonsCompleted: lessons)
    }

    @Test
    func recordingIsIdempotent() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AchievementStore(defaults: defaults)

        let first = store.recordUnlocks(for: stats(lessons: 1))
        let second = store.recordUnlocks(for: stats(lessons: 1))

        #expect(first.map(\.id) == ["lessons.1"])
        #expect(second.isEmpty, "a second call must not re-celebrate the same badge")
        #expect(store.unlockedIDs == ["lessons.1"])
    }

    @Test
    func onlyTheNewlyEarnedBadgesAreReturned() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AchievementStore(defaults: defaults)

        store.recordUnlocks(for: stats(streak: 3))
        let next = store.recordUnlocks(for: stats(streak: 7))

        #expect(next.map(\.id) == ["streak.7"], "the 3-day badge was already recorded")
    }

    /// The reason the ledger exists. A streak can break, and a learner who kept
    /// thirty days has still kept thirty days.
    @Test
    func aBrokenStreakDoesNotTakeTheBadgeBack() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AchievementStore(defaults: defaults)

        store.recordUnlocks(for: stats(streak: 30))
        #expect(store.unlockedIDs.contains("streak.30"))

        // The streak resets to 1 the next time they study after a missed day.
        store.recordUnlocks(for: stats(streak: 1))

        #expect(store.unlockedIDs.contains("streak.30"), "the unlock is a historical fact")
    }

    @Test
    func unlockDatesAreRecorded() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AchievementStore(defaults: defaults)

        let when = Date(timeIntervalSince1970: 1_700_000_000)
        store.recordUnlocks(for: stats(lessons: 1), now: when)

        #expect(store.unlockDate(for: "lessons.1") == when)
    }

    @Test
    func ledgerSurvivesANewStoreInstance() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AchievementStore(defaults: defaults).recordUnlocks(for: stats(lessons: 1))

        #expect(AchievementStore(defaults: defaults).unlockedIDs == ["lessons.1"])
    }

    @Test
    func aBadgeIsOwedACelebrationUntilItHasBeenShown() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AchievementStore(defaults: defaults)

        store.recordUnlocks(for: stats(lessons: 1))
        #expect(store.uncelebrated.map(\.id) == ["lessons.1"])

        store.markCelebrated(["lessons.1"])
        #expect(store.uncelebrated.isEmpty)
    }

    @Test
    func uncelebratedBadgesComeBackInCatalogueOrder() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AchievementStore(defaults: defaults)

        // Unlocks several at once, which a first long session can do.
        store.recordUnlocks(for: UserStats(
            currentStreak: 7,
            totalXP: 600,
            wordsSeen: 120,
            lessonsCompleted: 10
        ))

        let order = AchievementCatalog.all.map(\.id)
        let reported = store.uncelebrated.map(\.id)
        let expected = order.filter(reported.contains)

        #expect(reported == expected)
        #expect(reported.count > 1)
    }

    @Test
    func resetClearsTheLedgerAndTheCelebrationFlags() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AchievementStore(defaults: defaults)

        store.recordUnlocks(for: stats(streak: 7, lessons: 10))
        store.reset()

        #expect(store.unlockedIDs.isEmpty)
        #expect(store.uncelebrated.isEmpty)
    }

    /// An id in storage that the catalogue no longer defines must be left out
    /// of what the app counts, but kept in storage so a downgrade does not lose
    /// it.
    ///
    /// Counting it was a real defect: Profile renders the unlocked count over
    /// `AchievementCatalog.all.count`, so one stale id reads as "13/12", and
    /// the `unlocked < all` guard then hides the "next up" row for good.
    @Test
    func anUnknownStoredIDIsNotCountedButIsNotDestroyed() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let stale = "achievement.removed.in.a.later.version"
        let ledger = [stale: Date(), "lessons.1": Date()]
        defaults.set(try! JSONEncoder().encode(ledger), forKey: "gjuha.achievements.unlockedAt.v1")

        let store = AchievementStore(defaults: defaults)

        #expect(store.unlockedIDs == ["lessons.1"], "a stale id must not be counted")
        #expect(store.unlockedAt.count <= AchievementCatalog.all.count)
        #expect(store.uncelebrated.map(\.id) == ["lessons.1"])
        #expect(
            store.storedIDsIncludingUnknown.contains(stale),
            "the row must stay in storage so a downgrade does not lose it"
        )
    }

    /// The count Profile divides by the catalogue size can never exceed it.
    @Test
    func theUnlockedCountNeverExceedsTheCatalogue() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var ledger = [String: Date]()
        for id in AchievementCatalog.all.map(\.id) { ledger[id] = Date() }
        for n in 0..<5 { ledger["removed.milestone.\(n)"] = Date() }
        defaults.set(try! JSONEncoder().encode(ledger), forKey: "gjuha.achievements.unlockedAt.v1")

        let store = AchievementStore(defaults: defaults)
        #expect(store.unlockedAt.count == AchievementCatalog.all.count)
    }
}

// MARK: - Stored payload compatibility

/// Both of these structs gained fields after the app was already installable, so
/// both have to decode a payload written by the previous version. The failure
/// mode is quiet in each case: a learner mid-lesson loses their place, or a
/// placed widget falls back to a placeholder.
struct StoredPayloadCompatibilityTests {

    /// A lesson snapshot with the new keys stripped back out, which is exactly
    /// the shape the previous app version wrote.
    ///
    /// Built by encoding a real snapshot and deleting the two keys, rather than
    /// by hand-writing the whole payload: a hand-written fixture drifts from the
    /// model's actual schema and then tests nothing but itself.
    @Test
    func aPreUpgradeLessonSessionStillRestores() throws {
        let snapshot = Self.sampleSession
        var object = try Self.jsonObject(from: snapshot)
        object.removeValue(forKey: "answeredCount")
        object.removeValue(forKey: "correctCount")

        #expect(object["combo"] != nil, "the fixture is still a lesson session")

        let data = try JSONSerialization.data(withJSONObject: object)
        let restored = try JSONDecoder().decode(LessonSessionSnapshot.self, from: data)

        #expect(restored.currentIndex == snapshot.currentIndex, "the learner keeps their place")
        #expect(restored.hearts == snapshot.hearts)
        #expect(restored.xpEarned == snapshot.xpEarned)
        #expect(restored.combo == snapshot.combo)
        #expect(restored.answeredCount == 0, "absent counters default rather than throw")
        #expect(restored.correctCount == 0)
    }

    /// The best combo survives a termination. It was not persisted, so a
    /// learner who reached 6x, slipped to 0, then resumed and finished was told
    /// their best streak was 0: the same under-reporting the counters were
    /// added to fix.
    @Test
    func theBestComboSurvivesAResume() throws {
        let original = LessonSessionSnapshot(
            lesson: Self.sampleSession.lesson,
            exercises: [],
            currentIndex: 7,
            hearts: 2,
            xpEarned: 80,
            combo: 0,
            answeredCount: 8,
            correctCount: 6,
            bestCombo: 6,
            savedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(LessonSessionSnapshot.self, from: data)

        #expect(restored.combo == 0, "the live combo really was broken")
        #expect(restored.bestCombo == 6, "but the attempt really did reach 6")
    }

    /// A payload from before the field existed falls back to `combo`, which is
    /// the best run still going when it was written.
    @Test
    func aPreUpgradeSnapshotInfersTheBestComboFromTheLiveOne() throws {
        var object = try Self.jsonObject(from: Self.sampleSession)
        object.removeValue(forKey: "bestCombo")
        object["combo"] = 3

        let data = try JSONSerialization.data(withJSONObject: object)
        let restored = try JSONDecoder().decode(LessonSessionSnapshot.self, from: data)

        #expect(restored.bestCombo == 3)
    }

    @Test
    func aLessonSessionRoundTripsWithItsNewCounters() throws {
        let original = Self.sampleSession
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(LessonSessionSnapshot.self, from: data)

        #expect(restored.answeredCount == 5)
        #expect(restored.correctCount == 4)
        #expect(restored == original)
    }

    static let sampleSession = LessonSessionSnapshot(
        lesson: LessonSummary(
            seedId: "u1-l2",
            title: "Numbers",
            subtitle: "One to ten",
            iconName: "number",
            lessonType: .vocabulary,
            orderIndex: 1
        ),
        exercises: [],
        currentIndex: 3,
        hearts: 2,
        xpEarned: 45,
        combo: 2,
        answeredCount: 5,
        correctCount: 4,
        savedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    static func jsonObject<T: Encodable>(from value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    /// A widget projection with the goal keys stripped out, which is the shape
    /// the previous app version wrote. It has to keep serving a correct streak
    /// and due count, and simply omit the ring.
    @Test
    func aPreUpgradeWidgetSnapshotStillDecodes() throws {
        var object = try Self.jsonObject(from: GjuhaWidgetSnapshot.gallerySample)
        object.removeValue(forKey: "xpToday")
        object.removeValue(forKey: "dailyGoalXP")

        let data = try JSONSerialization.data(withJSONObject: object)
        let snapshot = try JSONDecoder().decode(GjuhaWidgetSnapshot.self, from: data)

        #expect(snapshot.currentStreak == GjuhaWidgetSnapshot.gallerySample.currentStreak)
        #expect(snapshot.dueReviewCount == GjuhaWidgetSnapshot.gallerySample.dueReviewCount)
        #expect(snapshot.nextLessonTitle == GjuhaWidgetSnapshot.gallerySample.nextLessonTitle)
        #expect(snapshot.xpToday == 0)
        #expect(snapshot.dailyGoalXP == 0)
        #expect(snapshot.dailyGoalProgress == 0)
        #expect(!snapshot.hasMetDailyGoal, "a missing goal is not a met goal")
    }

    @Test
    func aWidgetSnapshotRoundTripsWithItsGoal() throws {
        let original = GjuhaWidgetSnapshot(
            currentStreak: 4,
            totalXP: 300,
            dueReviewCount: 0,
            wordsMastered: 8,
            nextLessonTitle: "At the market",
            practicedToday: true,
            xpToday: 90,
            dailyGoalXP: 120,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(GjuhaWidgetSnapshot.self, from: data)

        #expect(restored == original)
        #expect(restored.dailyGoalProgress == 0.75)
    }

    /// The placeholder must not claim a met goal, which a zero/zero comparison
    /// would do if `hasMetDailyGoal` were written as `xpToday >= dailyGoalXP`.
    @Test
    func thePlaceholderClaimsNoGoalProgress() {
        #expect(!GjuhaWidgetSnapshot.placeholder.hasMetDailyGoal)
        #expect(GjuhaWidgetSnapshot.placeholder.dailyGoalProgress == 0)
    }
}

// MARK: - Surfaces

/// The content-layer surface and its accessibility fallbacks.
///
/// `GjuhaSurfaceStyle.resolve` exists as a pure function precisely so this suite
/// can assert it. A `ViewModifier` cannot be inspected from a unit test, so
/// without the split the Reduce Transparency answer would be a comment with
/// nothing behind it, which is the state the app was in before: roughly thirty
/// surfaces built on a material and not one of them checked the setting.
struct GjuhaSurfaceTests {

    private func resolve(
        _ prominence: GjuhaSurfaceProminence,
        reduceTransparency: Bool = false,
        increaseContrast: Bool = false
    ) -> GjuhaSurfaceResolution {
        GjuhaSurfaceStyle.resolve(
            prominence: prominence,
            reduceTransparency: reduceTransparency,
            increaseContrast: increaseContrast
        )
    }

    /// The headline guarantee: ask for less transparency and nothing translucent
    /// is left on any surface, at any prominence, with or without Increase
    /// Contrast also on.
    @Test
    func reduceTransparencyLeavesNothingTranslucent() {
        for prominence in [GjuhaSurfaceProminence.nested, .standard, .prominent] {
            for contrast in [false, true] {
                let resolved = resolve(
                    prominence,
                    reduceTransparency: true,
                    increaseContrast: contrast
                )
                #expect(
                    !resolved.isTranslucent,
                    "\(prominence) stayed translucent under Reduce Transparency (contrast: \(contrast))"
                )
            }
        }
    }

    /// And a nested surface stays distinguishable from the card it sits in, which
    /// is the one thing going opaque could have broken: both resolving to
    /// `surface` would make a stat tile invisible inside its own card.
    @Test
    func anOpaqueNestedSurfaceStillSeparatesFromItsParent() {
        let parent = resolve(.standard, reduceTransparency: true)
        let child = resolve(.nested, reduceTransparency: true)

        #expect(parent.fill == .opaqueSurface)
        #expect(child.fill == .opaqueSurfaceSecondary)
        #expect(parent.fill != child.fill)
    }

    /// Text-bearing surfaces get the regular material, not the ultra-thin one
    /// they used to have. Apple's Materials guidance: thicker materials give
    /// better contrast for text and fine detail.
    @Test
    func textBearingSurfacesUseTheThickerMaterial() {
        #expect(resolve(.standard).fill == .regularMaterial)
        #expect(resolve(.prominent).fill == .regularMaterial)
    }

    /// `.prominent` has to actually be more prominent. It previously resolved
    /// identically to `.standard`, which made it a dead enum case: the eight
    /// cards that lead a screen asked for emphasis and silently got none.
    @Test
    func prominentLiftsFurtherOffThePageThanStandard() {
        for transparency in [false, true] {
            let standard = resolve(.standard, reduceTransparency: transparency)
            let prominent = resolve(.prominent, reduceTransparency: transparency)
            #expect(
                prominent.shadowRadius > standard.shadowRadius,
                "prominent did not lift further (reduceTransparency: \(transparency))"
            )
            #expect(prominent.shadowOpacity > standard.shadowOpacity)
        }
    }

    /// And a nested surface lifts not at all, at every setting.
    @Test
    func aNestedSurfaceNeverCastsAShadow() {
        for transparency in [false, true] {
            let nested = resolve(.nested, reduceTransparency: transparency)
            #expect(!nested.hasShadow)
            #expect(nested.shadowRadius == 0)
            #expect(nested.shadowOpacity == 0)
        }
    }

    /// A surface drawn inside another surface carries no material and no shadow.
    /// Material on material is the stacked-glass case that blurs the hierarchy
    /// the material exists to create, and two nested shadows describe a depth
    /// no physical arrangement has.
    @Test
    func aNestedSurfaceNeitherStacksMaterialNorShadow() {
        let nested = resolve(.nested)
        #expect(nested.fill == .chipFill)
        #expect(!nested.hasShadow)
    }

    @Test
    func topLevelSurfacesKeepTheirShadow() {
        #expect(resolve(.standard).hasShadow)
        #expect(resolve(.prominent).hasShadow)
        #expect(resolve(.standard, reduceTransparency: true).hasShadow,
                "an opaque fill still reads as depth, so the shadow stays")
    }

    /// Increase Contrast widens the edge as well as darkening it. The `hairline`
    /// token already carries a stronger value in its increased-contrast
    /// appearance; the extra width is what makes a boundary unmistakable rather
    /// than merely darker.
    @Test
    func increaseContrastThickensEveryEdge() {
        for prominence in [GjuhaSurfaceProminence.nested, .standard, .prominent] {
            let normal = resolve(prominence)
            let high = resolve(prominence, increaseContrast: true)
            #expect(high.strokeWidth > normal.strokeWidth, "\(prominence) edge did not thicken")
        }
    }

    /// Every surface draws a border at every setting. The border is what marks a
    /// card's bounds once the material is gone, so it is never zero.
    @Test
    func everySurfaceDrawsABorder() {
        for prominence in [GjuhaSurfaceProminence.nested, .standard, .prominent] {
            for transparency in [false, true] {
                for contrast in [false, true] {
                    let resolved = resolve(
                        prominence,
                        reduceTransparency: transparency,
                        increaseContrast: contrast
                    )
                    #expect(resolved.strokeWidth > 0)
                }
            }
        }
    }

    /// Resolution is a pure function of its three inputs, with no hidden state.
    @Test
    func resolutionIsDeterministic() {
        #expect(resolve(.standard) == resolve(.standard))
        #expect(resolve(.nested, reduceTransparency: true) == resolve(.nested, reduceTransparency: true))
    }
}

// MARK: - Mascot animation

/// The mascot loop asset, which now feeds Image I/O instead of a `WKWebView`.
///
/// Worth checking rather than eyeballing, because the failure mode is silent: if
/// the asset stops decoding, the view falls back to the still image and looks
/// merely a bit flat, with nothing in the logs to say so.
///
/// What is *not* tested here is `MascotLoop.frames(from:)` itself.
/// `CGAnimateImageDataWithBlock` schedules its callbacks on a run loop, and a
/// unit test has none spinning, so awaiting that stream hangs rather than
/// failing. Driving it needs the app running, so it is a device-checklist item.
/// These tests cover the part that can be checked deterministically: that the
/// asset is a real multi-frame GIF that Image I/O can decode, which is the thing
/// that would actually break.
struct MascotLoopTests {

    @Test
    func theLoopAssetIsPresentAndIsAGIF() throws {
        let data = try #require(MascotLoop.data, "MascotLoop is missing from the asset catalog")
        #expect(data.count > 0)
        #expect(data.prefix(3) == Data("GIF".utf8))
    }

    /// Image I/O decodes it, and it has more than one frame. A single-frame GIF
    /// would animate to nothing while still passing a "is it a GIF" check.
    @Test
    func imageIODecodesEveryFrame() throws {
        let data = try #require(MascotLoop.data)
        let source = try #require(
            CGImageSourceCreateWithData(data as CFData, nil),
            "Image I/O could not open the asset"
        )

        let count = CGImageSourceGetCount(source)
        #expect(count > 1, "a loop needs more than one frame, found \(count)")

        // Spot-check the ends rather than every frame: a truncated GIF decodes
        // its first frames and fails on its last.
        for index in [0, count - 1] {
            let frame = CGImageSourceCreateImageAtIndex(source, index, nil)
            let image = try #require(frame, "frame \(index) of \(count) failed to decode")
            #expect(image.width > 0 && image.height > 0)
        }
    }

    /// The still fallback has to exist too, because it is what Reduce Motion and
    /// a missing loop both fall back to.
    @Test
    func theStillFallbackImageExists() {
        #expect(UIImage(named: "MascotIcon") != nil, "MascotIcon is missing from the asset catalog")
    }
}

// MARK: - Test-reset completeness

/// Guards the hook that gives every UI test a clean first launch.
///
/// It used to name each key by hand, with a comment claiming the list was
/// complete. The claim went stale: the daily XP keys and the achievement ledger
/// were added later and never reached it, so a UI test "starting from a known
/// first-launch position" actually started with the previous run's XP and
/// badges. The symptom was a Profile screen reporting 97 XP earned today, zero
/// lessons completed, and an unlocked achievement, all at once.
///
/// These assert the property that matters, that nothing a learner can
/// accumulate survives the reset, rather than re-listing the keys here. A list
/// in a test goes stale exactly like a list in the source.
struct TestResetCompletenessTests {

    /// Every store the reset delegates to must clear what it owns, so a
    /// first-launch UI test cannot inherit anything.
    @Test
    func everyLearnerOwnedStoreClearsItself() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let progress = ProgressStore(defaults: defaults)
        let achievements = AchievementStore(defaults: defaults)

        // Accumulate the things a learner accumulates.
        progress.markLessonCompleted(seedId: "u1-l1", xpEarned: 97)
        achievements.recordUnlocks(for: UserStats(
            currentStreak: 1, totalXP: 97, wordsSeen: 10, lessonsCompleted: 1
        ))

        #expect(progress.totalXP == 97)
        #expect(progress.xpEarnedToday == 97)
        #expect(progress.lessonsCompleted == 1)
        #expect(!achievements.unlockedIDs.isEmpty)

        progress.resetLearningProgress()
        achievements.reset()

        // The exact contradiction the stale list produced: XP earned today with
        // no lesson behind it, and a badge with no progress behind it.
        #expect(progress.xpEarnedToday == 0, "today's XP survived the reset")
        #expect(progress.totalXP == 0)
        #expect(progress.lessonsCompleted == 0)
        #expect(progress.currentStreak == 0)
        #expect(achievements.unlockedIDs.isEmpty, "the achievement ledger survived the reset")
        #expect(achievements.uncelebrated.isEmpty)
    }

    /// Stats rebuilt after a reset must be internally consistent: no figure may
    /// imply work that another figure denies.
    @Test
    func statsAfterAResetCannotContradictThemselves() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let progress = ProgressStore(defaults: defaults)
        progress.markLessonCompleted(seedId: "u1-l1", xpEarned: 97)
        progress.resetLearningProgress()

        let stats = UserStats(
            currentStreak: progress.currentStreak,
            totalXP: progress.totalXP,
            wordsSeen: 0,
            lessonsCompleted: progress.lessonsCompleted,
            xpToday: progress.xpEarnedToday,
            dailyGoalXP: LearningGoal.regular.dailyXPGoal
        )

        #expect(
            stats.xpToday <= stats.totalXP,
            "XP earned today cannot exceed XP earned ever"
        )
        #expect(
            !(stats.xpToday > 0 && stats.lessonsCompleted == 0),
            "XP today with no completed lesson is the contradiction this guards"
        )
        #expect(!stats.hasMetDailyGoal)
    }
}
