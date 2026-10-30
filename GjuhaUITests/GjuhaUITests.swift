import XCTest

/// Critical-flow UI tests.
///
/// These cover the handful of paths that, if broken, make the app unusable and
/// that no unit test can reach: the first-run experience, root navigation, the
/// exercise screen, and the destructive-action confirmations. They are
/// deliberately few. UI tests are slow and flaky in proportion to how much they
/// assert, so the detailed behaviour (scheduling, grading, resume, progress
/// accounting) stays in the fast unit suite, which is where it belongs.
///
/// Every test starts from a wiped device via the DEBUG-only
/// `-GjuhaResetStateForUITests` launch argument, so no test depends on the order
/// it runs in or on state another test left behind.
final class GjuhaUITests: XCTestCase {

    /// Generous because the launch sequence includes a deliberate splash
    /// animation before the first interactive screen appears.
    private let timeout: TimeInterval = 30

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Interacting

    /// Taps an element once it is genuinely tappable.
    ///
    /// `waitForExistence` alone is not enough in this app. The launch sequence
    /// keeps an animated splash over the UI and renders the real screen beneath
    /// it at `opacity(0.001)`, so every control underneath is already in the
    /// accessibility tree and reports `exists == true` while still being covered.
    /// A tap synthesised in that window lands on the splash and is swallowed,
    /// which shows up as "the button did nothing" rather than as a failure.
    /// Waiting for `isHittable` closes that window.
    @discardableResult
    private func tap(
        _ element: XCUIElement,
        _ description: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        guard element.waitForExistence(timeout: timeout) else {
            XCTFail("\(description) never appeared.", file: file, line: line)
            return false
        }

        // Two distinct reasons an existing element is not yet tappable, handled
        // in order because they need opposite responses.
        //
        // 1. It is covered by the launch splash, which needs waiting out.
        // 2. It is below the fold, which needs scrolling. Waiting forever on a
        //    control that is simply off screen is the slow way to fail.
        if !waitForHittable(element) {
            scrollIntoView(element)
        }

        guard canBeTapped(element) else {
            XCTFail(
                "\(description) existed but never became tappable, even after scrolling.",
                file: file,
                line: line
            )
            return false
        }
        element.tap()
        return true
    }

    /// Waits out the launch splash, which renders the real UI beneath it at
    /// `opacity(0.001)`: every control under it already reports `exists == true`
    /// while still being covered, and a tap in that window is swallowed.
    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if canBeTapped(element) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
    }

    /// Whether an element can be tapped right now, without raising.
    ///
    /// `isHittable` does not return false for an element that has no usable
    /// frame: it raises "Activation point invalid and no suggested hit points
    /// based on element frame" and fails the test outright. SwiftUI's lazy
    /// containers publish a row to the accessibility tree before laying it out,
    /// so a control below the fold is in exactly that state, and the query
    /// meant to discover that fact is the thing that fails.
    ///
    /// Checking the frame first turns an unanswerable question into "not yet",
    /// which is what the callers can actually act on by scrolling.
    private func canBeTapped(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        guard frame.width > 0, frame.height > 0 else { return false }
        return element.isHittable
    }

    /// Scrolls an off-screen control into view. Profile in particular is longer
    /// than one screen, so the reset control sits below the fold.
    private func scrollIntoView(_ element: XCUIElement, maxSwipes: Int = 8) {
        let scrollView = XCUIApplication().scrollViews.firstMatch
        let scroller: XCUIElement = scrollView.exists ? scrollView : XCUIApplication()
        for _ in 0..<maxSwipes where !canBeTapped(element) {
            scroller.swipeUp()
            // Let the swipe settle, so the next check reads a laid out frame
            // rather than one mid animation.
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
    }

    // MARK: - Finding a tab

    /// A top-level destination, wherever the system decided to put it.
    ///
    /// `app.buttons["Words"]` was enough while the app drew its own tab bar. It
    /// is not enough now: the app uses a real `TabView` with
    /// `.tabViewStyle(.sidebarAdaptable)`, so at a regular width iPadOS presents
    /// the same four destinations through a different control, and a query that
    /// names only `buttons` finds nothing. That is a difference in presentation,
    /// not in behaviour, so the test should follow the system rather than assert
    /// one shape of it.
    ///
    /// Tried in order of how specific they are, and a hittable match always wins
    /// over one that merely exists, because a destination can be present in the
    /// accessibility tree while covered by the launch splash.
    ///
    /// Every query is `.firstMatch`, which is what made this fail on iPad: there
    /// the system publishes each tab button *twice*, as a wrapper and the button
    /// inside it, so a plain `app.buttons["Words"]` subscript is ambiguous and
    /// resolving it reports the element as existing but never hittable. The two
    /// are the same destination, so taking the first is correct rather than a
    /// workaround.
    private func tabElement(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let candidates = [
            app.tabBars.buttons[name].firstMatch,
            app.buttons[name].firstMatch,
            app.collectionViews.buttons[name].firstMatch,
            app.cells[name].firstMatch,
            app.staticTexts[name].firstMatch
        ]
        if let hittable = candidates.first(where: { $0.exists && $0.isHittable }) {
            return hittable
        }
        if let existing = candidates.first(where: { $0.exists }) {
            return existing
        }
        // Nothing matched. Return the plain button query so the failure message
        // names what the test was actually looking for.
        return app.buttons[name].firstMatch
    }

    /// Waits for a destination to be present, in whichever presentation.
    @discardableResult
    private func waitForTab(_ name: String, in app: XCUIApplication) -> Bool {
        if tabElement(name, in: app).waitForExistence(timeout: timeout) { return true }
        // `tabElement` resolves once; if the first resolution lost the race with
        // the launch splash, re-resolve and wait again.
        return tabElement(name, in: app).waitForExistence(timeout: timeout)
    }

    // MARK: - Launching

    private func launchApp(resetState: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        if resetState {
            app.launchArguments += ["-GjuhaResetStateForUITests"]
        }
        // Cuts the splash animation short and makes the whole run faster and
        // steadier, without changing any behaviour under test.
        app.launchArguments += ["-UIAccessibilityReduceMotionEnabled", "1"]
        app.launch()
        return app
    }

    // MARK: - First run

    func testOnboardingLeadsToTheLessonMap() throws {
        let app = launchApp()

        tap(app.buttons["Get started"], "The onboarding welcome button")

        // Reason step. Any reason is fine; the flow must not require one.
        tap(app.buttons["Travel"], "A learning reason")
        tap(app.buttons["Continue"], "Continue past the reason step")

        // Goal step.
        tap(
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Regular")).firstMatch,
            "A daily goal"
        )
        tap(app.buttons["Start learning"], "Finish onboarding")

        // The root tab bar is the proof we reached the app proper.
        XCTAssertTrue(
            waitForTab("Learn", in: app),
            "Finishing onboarding should reveal the root destinations."
        )
    }

    func testOnboardingIsNotShownAgainAfterItIsCompleted() throws {
        completeOnboarding(on: launchApp())

        // Relaunch WITHOUT resetting: onboarding must be remembered.
        let app = launchApp(resetState: false)
        XCTAssertTrue(
            waitForTab("Learn", in: app),
            "A returning learner should go straight to the lesson map."
        )
        XCTAssertFalse(
            app.buttons["Get started"].exists,
            "Onboarding should not reappear once it has been completed."
        )
    }

    // MARK: - Root navigation

    func testEveryRootTabOpens() throws {
        let app = launchApp()
        completeOnboarding(on: app)

        for tab in ["Words", "Grammar", "Profile", "Learn"] {
            tap(tabElement(tab, in: app), "The \(tab) tab")
            XCTAssertTrue(
                waitForTab(tab, in: app),
                "\(tab) tab vanished after tapping it."
            )
        }
    }

    /// The Profile screen is where Gjuha makes its honest-progress claim, so the
    /// three distinct figures must actually be on screen and distinguishable.
    func testProfileSeparatesExposureFromMastery() throws {
        let app = launchApp()
        completeOnboarding(on: app)

        tap(tabElement("Profile", in: app), "The Profile tab")

        for label in ["Words seen", "In review", "Mastered"] {
            XCTAssertTrue(
                app.staticTexts[label].waitForExistence(timeout: timeout),
                "Profile should distinguish '\(label)' from the other progress figures."
            )
        }
    }

    /// The daily goal is the loop the whole header is built around: the learner
    /// picks one during onboarding, and before this release nothing in the app
    /// ever showed progress against it. If the ring stops rendering, the goal
    /// silently becomes invisible again, which no unit test can catch.
    func testHomeShowsProgressTowardTheDailyGoal() throws {
        let app = launchApp()
        completeOnboarding(on: app)

        // The ring is one accessibility element exposing its label and the real
        // figures as its value, so this also checks it is reachable by VoiceOver
        // rather than being a decorative shape.
        let ring = app.otherElements["Today's goal"]
        XCTAssertTrue(
            ring.waitForExistence(timeout: timeout),
            "Home should show progress toward today's goal."
        )

        // "Regular" is the goal `completeOnboarding` selects, which is 120 XP.
        // A fresh account has earned nothing yet, so the ring must say 0 of 120
        // rather than inventing progress.
        //
        // Waited for rather than read once: Home renders the ring immediately
        // from `UserStats.empty`, whose `dailyGoalXP` defaults to the casual
        // goal of 60, and the chosen 120 only arrives with the asynchronous
        // `statsLoaded`. Reading the value straight after `waitForExistence`
        // legitimately catches the 60 on a slow simulator.
        let namesTheGoal = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS %@", "120"),
            object: ring
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [namesTheGoal], timeout: timeout),
            .completed,
            "The goal ring should name the chosen goal. Value was: \(String(describing: ring.value))"
        )
    }

    /// Achievements must be visible and honestly locked on a fresh account: the
    /// grid is the one place the app makes a claim about what the learner has
    /// achieved, so it must not start out claiming anything.
    func testAchievementsStartLockedAndAreReachable() throws {
        let app = launchApp()
        completeOnboarding(on: app)

        tap(tabElement("Profile", in: app), "The Profile tab")

        XCTAssertTrue(
            app.staticTexts["Achievements"].waitForExistence(timeout: timeout),
            "Profile should have an Achievements section."
        )

        let firstSteps = app.otherElements["First steps"]
        scrollIntoView(firstSteps)
        XCTAssertTrue(
            firstSteps.waitForExistence(timeout: timeout),
            "The first-lesson achievement should be in the grid."
        )
        XCTAssertTrue(
            (firstSteps.value as? String)?.contains("Locked") == true,
            "A fresh account must not start with achievements unlocked. Value was: \(String(describing: firstSteps.value))"
        )
    }

    // MARK: - Lessons

    /// Opening a lesson presents the exercise screen, and leaving it before
    /// answering anything does *not* nag.
    ///
    /// That second half is the real assertion. `LessonFeature` only raises the
    /// quit confirmation once `currentIndex > 0 || xpEarned > 0`, so a learner who
    /// opens a lesson and immediately changes their mind is let straight back out.
    /// The confirmation exists to protect answered questions, not to make leaving
    /// difficult, and a test that demanded a dialog here would be enforcing the
    /// opposite of the intended behaviour.
    ///
    /// The confirm-after-progress path is covered in the unit suite
    /// (`LessonResumeTests`, which exercises the snapshot and discard logic
    /// directly), and the destructive-confirmation pattern itself is covered by
    /// the reset test below. Driving a generated exercise to a correct answer from
    /// a UI test would mean depending on which exercise type the engine happened
    /// to produce, which is not a stable thing to assert on.
    func testOpeningALessonShowsAnExerciseAndLeavingEarlyDoesNotNag() throws {
        let app = launchApp()
        completeOnboarding(on: app)

        // The first lesson of the first unit is the only one unlocked on a fresh
        // install, so whatever is tappable here is it.
        let firstLesson = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Greetings")
        ).firstMatch
        XCTAssertTrue(
            firstLesson.waitForExistence(timeout: timeout),
            "The first unit's opening lesson should be on the lesson map."
        )
        tap(firstLesson, "The first lesson on the map")

        // An exercise screen is identifiable by its exit control.
        let exit = app.buttons["Exit lesson"]
        XCTAssertTrue(
            exit.waitForExistence(timeout: timeout),
            "Opening a lesson should present the exercise screen."
        )

        tap(exit, "Exit lesson")

        XCTAssertTrue(
            waitForTab("Learn", in: app),
            "Leaving a lesson with nothing answered should return to the lesson map."
        )
        XCTAssertFalse(
            app.alerts["Quit lesson?"].exists,
            "There is nothing to discard yet, so leaving must not ask for confirmation."
        )
    }

    // MARK: - Destructive actions

    func testResettingLearningDataAsksForConfirmationAndCanBeCancelled() throws {
        let app = launchApp()
        completeOnboarding(on: app)

        tap(tabElement("Profile", in: app), "The Profile tab")

        let reset = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Reset learning data")
        ).firstMatch
        tap(reset, "Reset learning data")

        let resetAlert = app.alerts["Reset learning data?"]
        XCTAssertTrue(
            resetAlert.waitForExistence(timeout: timeout),
            "A destructive reset must confirm first."
        )
        XCTAssertTrue(
            resetAlert.buttons["Reset"].exists,
            "The confirmation should offer an explicit Reset action."
        )

        tap(resetAlert.buttons["Cancel"], "Cancel the reset confirmation")
        XCTAssertTrue(
            reset.waitForExistence(timeout: timeout),
            "Cancelling the reset should return to Profile with nothing changed."
        )
        XCTAssertFalse(resetAlert.exists, "The reset confirmation should be dismissed.")
    }

    // MARK: - Helpers

    /// Walks the onboarding flow so a test can start from the lesson map.
    private func completeOnboarding(on app: XCUIApplication) {
        let getStarted = app.buttons["Get started"]
        guard getStarted.waitForExistence(timeout: timeout) else {
            // Already onboarded (a relaunch without a reset). Nothing to do.
            return
        }
        tap(getStarted, "The onboarding welcome button")
        tap(app.buttons["Travel"], "A learning reason")
        tap(app.buttons["Continue"], "Continue past the reason step")
        tap(
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Regular")).firstMatch,
            "A daily goal"
        )
        tap(app.buttons["Start learning"], "Finish onboarding")

        _ = waitForTab("Learn", in: app)
    }
}
