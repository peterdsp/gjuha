import Testing
import Foundation
@testable import Gjuha

// Tests for the release surfaces added for 1.0: the external entry points
// (widget taps, Siri, Shortcuts), the widget's projection of learner state, and
// the rule that decides which lesson "continue learning" opens.
//
// Like the rest of this target these are pure logic tests resolved through the
// app host, because the test bundle cannot link ComposableArchitecture on this
// toolchain (see the note in project.yml). The reducer cases that use these
// rules are thin wrappers over them.

// MARK: - Deep links

/// The `gjuha://` URLs are a published contract: a widget already placed on
/// someone's Home Screen keeps opening the URL it was built with, so these exact
/// strings must not drift.
struct DeepLinkTests {

    @Test
    func everyLinkRoundTripsThroughItsURL() {
        for link in [GjuhaDeepLink.startReview, .continueLearning, .progress] {
            #expect(GjuhaDeepLink(url: link.url) == link)
        }
    }

    @Test
    func urlStringsAreTheShippedContract() {
        #expect(GjuhaDeepLink.startReview.url.absoluteString == "gjuha://review")
        #expect(GjuhaDeepLink.continueLearning.url.absoluteString == "gjuha://continue")
        #expect(GjuhaDeepLink.progress.url.absoluteString == "gjuha://progress")
    }

    @Test
    func foreignSchemesAreRejected() {
        #expect(GjuhaDeepLink(url: URL(string: "https://example.com/review")!) == nil)
        #expect(GjuhaDeepLink(url: URL(string: "otherapp://review")!) == nil)
    }

    @Test
    func unknownHostsAreRejectedRatherThanGuessed() {
        #expect(GjuhaDeepLink(url: URL(string: "gjuha://delete-everything")!) == nil)
        #expect(GjuhaDeepLink(url: URL(string: "gjuha://")!) == nil)
    }

    @Test
    func schemeAndHostAreCaseInsensitive() {
        #expect(GjuhaDeepLink(url: URL(string: "GJUHA://Review")!) == .startReview)
    }

    /// Some callers produce a triple slash. Both shapes mean the same thing.
    @Test
    func tripleSlashFormIsAccepted() {
        #expect(GjuhaDeepLink(url: URL(string: "gjuha:///continue")!) == .continueLearning)
    }
}

// MARK: - Widget projection

struct WidgetProjectionTests {

    private func makeSnapshot(generatedAt: Date, dueReviewCount: Int = 3) -> GjuhaWidgetSnapshot {
        GjuhaWidgetSnapshot(
            currentStreak: 4,
            totalXP: 120,
            dueReviewCount: dueReviewCount,
            wordsMastered: 2,
            nextLessonTitle: "Coffee & ordering",
            practicedToday: false,
            generatedAt: generatedAt
        )
    }

    @Test
    func placeholderIsNotMistakenForRealData() {
        #expect(GjuhaWidgetSnapshot.placeholder.isRealData == false)
        #expect(GjuhaWidgetSnapshot.gallerySample.isRealData == true)
    }

    /// A placeholder has no numbers, so it must never be reported as stale: the
    /// widget needs to show "open to begin", not "open for today's numbers".
    @Test
    func placeholderIsNeverStale() {
        #expect(GjuhaWidgetSnapshot.placeholder.isStale(on: Date()) == false)
    }

    @Test
    func aSnapshotBuiltTodayIsCurrent() {
        let now = Date()
        #expect(makeSnapshot(generatedAt: now).isStale(on: now) == false)
    }

    /// The counts are day-relative, so once the day turns the widget must stop
    /// quoting them rather than show a figure that is probably wrong.
    @Test
    func aSnapshotFromYesterdayIsStale() {
        // A fixed calendar, so the result does not depend on the test machine.
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        #expect(makeSnapshot(generatedAt: yesterday).isStale(on: now, calendar: calendar) == true)
    }

    /// Minutes before midnight and minutes after are different days even though
    /// they are close together in absolute time.
    @Test
    func stalenessFollowsCalendarDaysNotElapsedHours() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Tirane")!

        let lateYesterday = calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 10, hour: 23, minute: 50)
        )!
        let earlyToday = calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 11, hour: 0, minute: 10)
        )!

        #expect(
            makeSnapshot(generatedAt: lateYesterday).isStale(on: earlyToday, calendar: calendar) == true,
            "20 minutes apart, but across midnight, so the counts are stale."
        )
        #expect(
            makeSnapshot(generatedAt: earlyToday).isStale(on: earlyToday, calendar: calendar) == false
        )
    }

    @Test
    func storeRoundTripsASnapshot() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WidgetSnapshotStore(defaults: defaults)
        #expect(store.load() == nil)

        let snapshot = makeSnapshot(generatedAt: Date())
        store.write(snapshot)

        let loaded = store.load()
        #expect(loaded?.currentStreak == snapshot.currentStreak)
        #expect(loaded?.dueReviewCount == snapshot.dueReviewCount)
        #expect(loaded?.nextLessonTitle == snapshot.nextLessonTitle)
    }

    @Test
    func clearRemovesTheProjection() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WidgetSnapshotStore(defaults: defaults)
        store.write(makeSnapshot(generatedAt: Date()))
        #expect(store.load() != nil)

        store.clear()
        #expect(store.load() == nil)
    }

    /// Corrupt or truncated data must degrade to "no projection", so the widget
    /// shows its placeholder instead of the extension crashing.
    @Test
    func corruptDataDecodesToNothingRatherThanCrashing() {
        let suiteName = "gjuha.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let key = "gjuha.widgetSnapshot.v1"
        let store = WidgetSnapshotStore(defaults: defaults)

        defaults.set(Data(), forKey: key)
        #expect(store.load() == nil)

        defaults.set(Data("not json".utf8), forKey: key)
        #expect(store.load() == nil)

        defaults.set(Data(#"{"currentStreak":1}"#.utf8), forKey: key)
        #expect(store.load() == nil, "A partial object is missing required fields and must not decode.")
    }

    /// An unavailable App Group must not take the app down with it.
    @Test
    func anUnavailableSuiteIsSurvivable() {
        let store = WidgetSnapshotStore(defaults: nil)
        store.write(makeSnapshot(generatedAt: Date()))
        store.clear()
        #expect(store.load() == nil)
    }
}

// MARK: - Which lesson "continue learning" opens

struct ContinueLearningTests {

    private func lesson(
        _ id: String,
        order: Int,
        completed: Bool = false,
        locked: Bool = false
    ) -> LessonSummary {
        LessonSummary(
            seedId: id,
            title: id,
            subtitle: "",
            iconName: "book.closed.fill",
            lessonType: .vocabulary,
            isCompleted: completed,
            isLocked: locked,
            orderIndex: order
        )
    }

    private func unit(_ order: Int, _ lessons: [LessonSummary]) -> LearningUnit {
        LearningUnit(
            id: UUID(),
            title: "Unit \(order)",
            description: "",
            cefrLevel: .a1,
            orderIndex: order,
            lessons: lessons
        )
    }

    @Test
    func picksTheFirstLessonThatIsNeitherDoneNorLocked() {
        let units = [
            unit(0, [
                lesson("a", order: 0, completed: true),
                lesson("b", order: 1, completed: true),
                lesson("c", order: 2)
            ]),
            unit(1, [lesson("d", order: 0)])
        ]
        #expect(AppFeature.nextOpenableLesson(in: units)?.seedId == "c")
    }

    @Test
    func skipsLockedLessonsEvenWhenTheyComeFirst() {
        let units = [unit(0, [
            lesson("locked", order: 0, locked: true),
            lesson("open", order: 1)
        ])]
        #expect(AppFeature.nextOpenableLesson(in: units)?.seedId == "open")
    }

    /// Order comes from `orderIndex`, not from however the array happens to be
    /// arranged, so a repository that returns units out of order still lands the
    /// learner in the right place.
    @Test
    func honoursOrderIndexRatherThanArrayOrder() {
        let units = [
            unit(1, [lesson("second-unit", order: 0)]),
            unit(0, [lesson("first-unit", order: 0)])
        ]
        #expect(AppFeature.nextOpenableLesson(in: units)?.seedId == "first-unit")

        let shuffledLessons = [unit(0, [
            lesson("later", order: 5),
            lesson("earlier", order: 1)
        ])]
        #expect(AppFeature.nextOpenableLesson(in: shuffledLessons)?.seedId == "earlier")
    }

    @Test
    func returnsNothingWhenEverythingReachableIsDone() {
        let units = [unit(0, [
            lesson("a", order: 0, completed: true),
            lesson("b", order: 1, completed: true, locked: false)
        ])]
        #expect(AppFeature.nextOpenableLesson(in: units) == nil)
    }

    @Test
    func returnsNothingForAnEmptyCurriculum() {
        #expect(AppFeature.nextOpenableLesson(in: []) == nil)
    }

    /// The widget's "next lesson" caption and the deep link must never disagree
    /// about which lesson is next, so both read the same rule.
    @Test
    func theWidgetCaptionMatchesTheLessonTheDeepLinkOpens() {
        let units = [
            unit(0, [lesson("done", order: 0, completed: true), lesson("next-one", order: 1)]),
            unit(1, [lesson("later", order: 0)])
        ]
        #expect(LiveWidgetSyncClient.nextLessonTitle(in: units) == "next-one")
        #expect(AppFeature.nextOpenableLesson(in: units)?.title == "next-one")
    }
}
