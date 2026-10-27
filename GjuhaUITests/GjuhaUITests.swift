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

        guard element.isHittable else {
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
        let hittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: element
        )
        return XCTWaiter.wait(for: [hittable], timeout: timeout) == .completed
    }

    /// Scrolls an off-screen control into view. Profile in particular is longer
    /// than one screen, so the reset control sits below the fold.
    private func scrollIntoView(_ element: XCUIElement, maxSwipes: Int = 8) {
        let scrollView = XCUIApplication().scrollViews.firstMatch
        let scroller: XCUIElement = scrollView.exists ? scrollView : XCUIApplication()
        for _ in 0..<maxSwipes where !element.isHittable {
            scroller.swipeUp()
        }
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
            app.buttons["Learn"].waitForExistence(timeout: timeout),
            "Finishing onboarding should reveal the root tab bar."
        )
    }

    func testOnboardingIsNotShownAgainAfterItIsCompleted() throws {
        completeOnboarding(on: launchApp())

        // Relaunch WITHOUT resetting: onboarding must be remembered.
        let app = launchApp(resetState: false)
        XCTAssertTrue(
            app.buttons["Learn"].waitForExistence(timeout: timeout),
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
            tap(app.buttons[tab], "The \(tab) tab")
            XCTAssertTrue(
                app.buttons[tab].waitForExistence(timeout: timeout),
                "\(tab) tab vanished after tapping it."
            )
        }
    }

    /// The Profile screen is where Gjuha makes its honest-progress claim, so the
    /// three distinct figures must actually be on screen and distinguishable.
    func testProfileSeparatesExposureFromMastery() throws {
        let app = launchApp()
        completeOnboarding(on: app)

        tap(app.buttons["Profile"], "The Profile tab")

        for label in ["Words seen", "In review", "Mastered"] {
            XCTAssertTrue(
                app.staticTexts[label].waitForExistence(timeout: timeout),
                "Profile should distinguish '\(label)' from the other progress figures."
            )
        }
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
            app.buttons["Learn"].waitForExistence(timeout: timeout),
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

        tap(app.buttons["Profile"], "The Profile tab")

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

        _ = app.buttons["Learn"].waitForExistence(timeout: timeout)
    }
}
