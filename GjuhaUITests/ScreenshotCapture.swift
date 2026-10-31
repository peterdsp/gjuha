import XCTest

/// Captures App Store screenshots at the required 6.9 inch size.
///
/// This is a tool, not a test of behaviour, so it skips unless it is asked for
/// by name. Without the guard it would add minutes to every CI run to produce
/// artwork nobody reads there.
///
///     GJUHA_CAPTURE=1 xcodebuild test \
///       -project Gjuha.xcodeproj -scheme Gjuha \
///       -destination 'platform=iOS Simulator,name=Gjuha-Shots-69' \
///       -only-testing:GjuhaUITests/ScreenshotCapture -skipMacroValidation
///
/// Run it on a 6.9 inch device (iPhone 17 Pro Max or 16 Pro Max), which produces
/// the 1320 x 2868 px images App Store Connect requires for that display size.
/// Easier still, `Scripts/capture_screenshots.sh` does all of the above and the
/// export in one command. Images land as attachments in the `.xcresult` bundle;
/// `Scripts/rename_screenshots.py` puts their readable names back.
///
/// Everything captured is real app state reached by driving the real UI. Nothing
/// is seeded, and in particular the lesson completion screen is not captured,
/// because its accuracy figure is derived from actual answers and a screenshot of
/// one that was not earned would be a claim about performance that did not happen.
final class ScreenshotCapture: XCTestCase {

    private let timeout: TimeInterval = 40

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["GJUHA_CAPTURE"] == "1",
            "Screenshot capture runs only when GJUHA_CAPTURE=1."
        )
    }

    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-GjuhaResetStateForUITests"]
        // Still images, so the ambient drift and the mascot loop do not land
        // mid-frame and smear a capture.
        app.launchArguments += ["-UIAccessibilityReduceMotionEnabled", "1"]
        app.launch()

        completeOnboarding(on: app)
        XCTAssertTrue(waitForTab("Learn", in: app), "Never reached the lesson map.")
        settle()

        capture(named: "01-Learn-lesson-map")

        openFirstLesson(in: app)
        capture(named: "02-Lesson-question")
        leaveLesson(in: app)

        tap(tabElement("Words", in: app), "Words tab")
        settle()
        capture(named: "03-Words-vocabulary")

        tap(tabElement("Grammar", in: app), "Grammar tab")
        settle()
        capture(named: "04-Grammar-guides")

        // Into a guide, because the conjugation table is behind a push and the
        // list above it shows none of what the screen is actually for.
        let guideRow = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "to be"))
            .firstMatch
        if guideRow.waitForExistence(timeout: 8) {
            tap(guideRow, "The first grammar guide")
            settle()
            capture(named: "05-Grammar-conjugation")
            if app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 5) {
                app.navigationBars.buttons.firstMatch.tap()
                settle()
            }
        }

        tap(tabElement("Profile", in: app), "Profile tab")
        settle()
        capture(named: "06-Profile-honest-progress")

        // Profile runs past one screen. One swipe lands on the achievement grid;
        // two carried straight past it to the settings blocks, which are not
        // what this capture is for.
        app.scrollViews.firstMatch.swipeUp()
        settle()
        capture(named: "07-Profile-achievements")
    }

    // MARK: - Capturing

    /// Attaches a full-screen capture that survives the test run.
    private func capture(named name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Lets animations and the launch splash finish before a capture, so no
    /// frame is taken mid-transition.
    private func settle(_ seconds: TimeInterval = 2.5) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    // MARK: - Driving

    private func completeOnboarding(on app: XCUIApplication) {
        tap(app.buttons["Get started"], "Onboarding welcome")
        tap(app.buttons["Travel"], "A learning reason")
        tap(app.buttons["Continue"], "Continue past the reason step")
        tap(
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Regular")).firstMatch,
            "A daily goal"
        )
        tap(app.buttons["Start learning"], "Finish onboarding")
    }

    /// Opens the first unlocked lesson on the map.
    private func openFirstLesson(in app: XCUIApplication) {
        let lesson = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "Greetings"))
            .firstMatch
        tap(lesson, "The first lesson")
        // The exercise screen builds its question after generating exercises.
        settle(4)
    }

    private func leaveLesson(in app: XCUIApplication) {
        let exit = app.buttons["Exit lesson"].firstMatch
        if exit.waitForExistence(timeout: timeout) {
            exit.tap()
            // A lesson with nothing answered leaves without confirming.
            let quit = app.alerts.buttons["Quit"].firstMatch
            if quit.waitForExistence(timeout: 3) { quit.tap() }
        }
        _ = waitForTab("Learn", in: app)
        settle()
    }

    // MARK: - Element lookup

    /// See the note on the same helper in `GjuhaUITests`: iPadOS publishes each
    /// tab button twice, so every query resolves `.firstMatch`.
    private func tabElement(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let candidates = [
            app.tabBars.buttons[name].firstMatch,
            app.buttons[name].firstMatch,
            app.collectionViews.buttons[name].firstMatch,
            app.cells[name].firstMatch
        ]
        if let hittable = candidates.first(where: { $0.exists && $0.isHittable }) { return hittable }
        if let existing = candidates.first(where: { $0.exists }) { return existing }
        return app.buttons[name].firstMatch
    }

    @discardableResult
    private func waitForTab(_ name: String, in app: XCUIApplication) -> Bool {
        tabElement(name, in: app).waitForExistence(timeout: timeout)
    }

    private func tap(_ element: XCUIElement, _ description: String) {
        guard element.waitForExistence(timeout: timeout) else {
            XCTFail("\(description) never appeared.")
            return
        }
        let hittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: element
        )
        _ = XCTWaiter.wait(for: [hittable], timeout: 12)
        guard element.isHittable else {
            XCTFail("\(description) existed but never became tappable.")
            return
        }
        element.tap()
    }
}
