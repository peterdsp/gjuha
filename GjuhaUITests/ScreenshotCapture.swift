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

        // The lesson map is captured after the lesson, not before: a fresh
        // account shows an empty ring and a zero streak, which is accurate and
        // useless as a lead image.
        openFirstLesson(in: app)
        capture(named: "02-Lesson-question")

        // Play it properly. Home with a part-filled ring and a real streak is
        // the screenshot that does the work, and a fresh account cannot show
        // one. Nothing is seeded: the exercises are solved from the shipped
        // vocabulary and answered through the real interface, so the XP and
        // streak that follow were earned.
        let finished = playLessonWithRetries(in: app)
        if finished {
            capture(named: "07-Lesson-complete")
            tap(app.buttons["Continue"], "Continue off the completion screen")
        } else {
            leaveLesson(in: app)
        }
        _ = waitForTab("Learn", in: app)

        // Home reloads its stats asynchronously after a lesson, so capturing on
        // a fixed delay caught the pre-refresh zeroes. Wait for the ring to stop
        // reading zero instead.
        if finished { waitForEarnedProgress(in: app) }
        settle()
        capture(named: "01-Learn-lesson-map")

        tap(tabElement("Words", in: app), "Words tab")
        settle()
        capture(named: "03-Words-vocabulary")

        tap(tabElement("Grammar", in: app), "Grammar tab")
        settle()
        capture(named: "04-Grammar-guides")

        tap(tabElement("Profile", in: app), "Profile tab")
        settle()
        capture(named: "05-Profile-honest-progress")

        // Profile runs past one screen. One swipe lands on the achievement grid;
        // two carried straight past it to the settings blocks, which are not
        // what this capture is for.
        app.scrollViews.firstMatch.swipeUp()
        settle()
        capture(named: "06-Profile-achievements")
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

    /// Leaves the lesson from whichever screen it ended on.
    ///
    /// There are three, and they offer different ways out: in progress has
    /// "Exit lesson" behind a confirmation, the completion screen has
    /// "Continue", and the out-of-hearts screen has "Back to lessons". Only the
    /// first was handled, so a run that ended out of hearts never got back to
    /// the tabs and the next tab tap failed with a message about the tab rather
    /// than about the lesson.
    private func leaveLesson(in app: XCUIApplication) {
        for label in ["Back to lessons", "Continue", "Exit lesson"] {
            let button = app.buttons[label].firstMatch
            guard button.waitForExistence(timeout: 3), button.isHittable else { continue }
            button.tap()
            if label == "Exit lesson" {
                let quit = app.alerts.buttons["Quit"].firstMatch
                if quit.waitForExistence(timeout: 3) { quit.tap() }
            }
            break
        }
        _ = waitForTab("Learn", in: app)
        settle()
    }


    // MARK: - Playing a lesson

    /// Plays the lesson, retrying from the out-of-hearts screen.
    ///
    /// A lesson shuffles its words and rotates exercise types, so one attempt
    /// can deal a mix the solver handles and the next can not. Retrying is
    /// cheaper and far less brittle than making the solver perfect, and it is
    /// what a learner does anyway.
    private func playLessonWithRetries(in app: XCUIApplication, attempts: Int = 3) -> Bool {
        for attempt in 1...attempts {
            if playLesson(in: app) { return true }

            let retry = app.buttons["Try again"].firstMatch
            guard attempt < attempts, retry.waitForExistence(timeout: 5), retry.isHittable else {
                return false
            }
            print("Attempt \(attempt) did not finish the lesson; retrying.")
            retry.tap()
            settle(4)
        }
        return false
    }

    /// Plays the open lesson to completion, answering correctly.
    ///
    /// Returns true when the completion screen appears. False is not a failure
    /// of the capture: the zero-state screenshots are still valid, so the caller
    /// carries on and simply has nothing extra to show.
    @discardableResult
    private func playLesson(in app: XCUIApplication) -> Bool {
        guard let solver = LessonSolver() else {
            print("No GJUHA_LEXICON supplied; leaving the lesson unplayed.")
            return false
        }

        // A lesson is capped at ten exercises; the extra iterations absorb the
        // grading pause between them.
        for _ in 0..<40 {
            if app.staticTexts["Lesson complete!"].exists { return true }
            if app.staticTexts["Out of hearts!"].exists {
                print("Ran out of hearts; leaving the lesson unplayed.")
                return false
            }
            guard let prompt = currentPrompt(in: app) else {
                settle(0.6)
                continue
            }
            answerCurrentExercise(prompt: prompt, solver: solver, in: app)
            // The app shows feedback for 1.4s before advancing.
            settle(2.0)
        }
        return app.staticTexts["Lesson complete!"].exists
    }

    /// Waits until Home's goal ring reflects the XP the lesson just banked.
    ///
    /// The ring renders immediately from `UserStats.empty`, and the real figures
    /// arrive with an asynchronous reload, so a capture on a fixed delay can
    /// catch "0 of 120" after a lesson worth 97 XP.
    private func waitForEarnedProgress(in app: XCUIApplication) {
        let ring = app.otherElements["Today's goal"].firstMatch
        guard ring.waitForExistence(timeout: timeout) else { return }

        let earned = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "NOT (value BEGINSWITH %@)", "0 of"),
            object: ring
        )
        if XCTWaiter.wait(for: [earned], timeout: 20) != .completed {
            print("Home still reads zero XP after the lesson: \(String(describing: ring.value))")
        }
    }

    /// The question on screen, found by the shapes the engine generates.
    private func currentPrompt(in app: XCUIApplication) -> String? {
        let leads = ["What does", "How do you say", "Translate:", "Arrange the words", "Match each word"]
        for text in app.staticTexts.allElementsBoundByIndex {
            let label = text.label
            if leads.contains(where: { label.hasPrefix($0) }) { return label }
            // A cloze prompt has no lead-in; it ends with its translation in
            // parentheses and contains the blank the engine writes.
            if label.contains("___") && label.contains("(") { return label }
        }
        return nil
    }

    private func answerCurrentExercise(
        prompt: String,
        solver: LessonSolver,
        in app: XCUIApplication
    ) {
        // Word matching: pair each Albanian with its English until none are left.
        if prompt.hasPrefix("Match each word") {
            solveWordMatch(solver: solver, in: app)
            return
        }

        guard let answer = solver.answer(forPrompt: prompt) else {
            print("Could not solve [\(prompt)]")
            tapFirstOption(in: app)
            return
        }

        // Word order: tap the tokens in the order the sentence needs.
        if prompt.hasPrefix("Arrange the words") {
            for token in answer.split(separator: " ").map(String.init) {
                let chip = app.buttons["Word \(token), tap to add"].firstMatch
                if chip.waitForExistence(timeout: 4), chip.isHittable { chip.tap() }
            }
            tapCheck(in: app)
            return
        }

        // Typed translation.
        let field = app.textFields.firstMatch
        if field.exists, field.isHittable {
            field.tap()
            field.typeText(answer)
            tapCheck(in: app)
            return
        }

        // Everything else is a set of option buttons.
        // Options carry the answer text as their label. Try the full string,
        // then the short gloss the engine renders in some places.
        for candidate in [answer, LessonSolver.shortGloss(answer)] {
            let option = app.buttons[candidate].firstMatch
            if option.waitForExistence(timeout: 3), option.isHittable {
                option.tap()
                return
            }
        }
        print("Answer [\(answer)] was not on screen for [\(prompt)]")
        tapFirstOption(in: app)
    }

    /// Taps each Albanian and then its English until every pair is matched.
    ///
    /// The English on a match tile is the *short gloss*, not the full seed
    /// string: the engine takes the part before any "/" or "(" and trims it, so
    /// "good day / hello" is shown as "good day". Looking up the full string
    /// finds no button, which is what stalled this loop the first time.
    private func solveWordMatch(solver: LessonSolver, in app: XCUIApplication) {
        var remainingBefore = -1

        for _ in 0..<12 {
            let unmatched = app.buttons.matching(
                NSPredicate(format: "value == %@", "not matched")
            ).allElementsBoundByIndex

            if unmatched.isEmpty { return }

            // A pass that matched nothing will not do better on the next one.
            // Bail out rather than spin: the caller then answers something so
            // the lesson moves on instead of hanging.
            if unmatched.count == remainingBefore {
                print("Word match made no progress with \(unmatched.count) tiles left.")
                return
            }
            remainingBefore = unmatched.count

            guard let albanian = unmatched.first(where: { solver.byAlbanian[$0.label] != nil }),
                  let entry = solver.byAlbanian[albanian.label] else { return }

            let englishButton = matchTile(for: entry, among: unmatched, in: app)
            guard let englishButton else {
                print("No tile for \(entry.e) (gloss \(LessonSolver.shortGloss(entry.e)))")
                return
            }

            if albanian.isHittable { albanian.tap() }
            if englishButton.isHittable { englishButton.tap() }
            settle(0.6)
        }
    }

    /// The tile showing this entry's English, trying the gloss the engine
    /// actually renders before the full string.
    private func matchTile(
        for entry: LexiconEntry,
        among unmatched: [XCUIElement],
        in app: XCUIApplication
    ) -> XCUIElement? {
        for candidate in [LessonSolver.shortGloss(entry.e), entry.e] {
            if let tile = unmatched.first(where: { $0.label == candidate }) { return tile }
            let button = app.buttons[candidate].firstMatch
            if button.exists { return button }
        }
        return nil
    }

    private func tapCheck(in app: XCUIApplication) {
        let check = app.buttons["Check"].firstMatch
        if check.waitForExistence(timeout: 4), check.isHittable { check.tap() }
    }

    /// Last resort when a prompt cannot be solved: answer something so the
    /// lesson moves on. Costs a heart, and three of those end the attempt.
    private func tapFirstOption(in app: XCUIApplication) {
        for button in app.buttons.allElementsBoundByIndex where button.isHittable {
            let label = button.label
            guard !label.isEmpty,
                  !["Check", "Exit lesson", "Continue", "Play audio"].contains(label),
                  !label.hasPrefix("Placed word") else { continue }
            button.tap()
            return
        }
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

// MARK: - Lesson solver

/// One vocabulary entry, as the capture script hands it over.
struct LexiconEntry: Decodable {
    let a: String   // Albanian
    let e: String   // English
    let s: String   // example sentence
    let t: String   // example translation
}

/// Answers a lesson correctly, so Home can be captured with progress a learner
/// would actually have.
///
/// Every answer is derived from the same seed vocabulary the app ships, handed
/// over by `Scripts/capture_screenshots.sh` in `GJUHA_LEXICON`. Nothing is
/// seeded into the app and no grading is bypassed: the exercises are solved and
/// tapped through the real interface, so the XP, streak and accuracy that end
/// up on screen were genuinely earned.
///
/// Keeping the lexicon out of this file is deliberate. A copy here would drift
/// the first time a word changed, and the failure would look like a flaky test
/// rather than stale data.
struct LessonSolver {
    let byAlbanian: [String: LexiconEntry]
    let byEnglish: [String: LexiconEntry]
    let byTranslation: [String: LexiconEntry]

    init?() {
        guard let raw = ProcessInfo.processInfo.environment["GJUHA_LEXICON"],
              let data = raw.data(using: .utf8),
              let entries = try? JSONDecoder().decode([LexiconEntry].self, from: data),
              !entries.isEmpty else { return nil }

        var albanian: [String: LexiconEntry] = [:]
        var english: [String: LexiconEntry] = [:]
        var translation: [String: LexiconEntry] = [:]
        for entry in entries {
            albanian[entry.a] = entry
            english[entry.e] = entry
            if !entry.t.isEmpty { translation[entry.t] = entry }
        }
        self.byAlbanian = albanian
        self.byEnglish = english
        self.byTranslation = translation
    }

    /// The answer an exercise prompt is asking for, or nil when the prompt is
    /// not one of the generated shapes.
    func answer(forPrompt prompt: String) -> String? {
        if let word = quoted(in: prompt, after: "What does") {
            return byAlbanian[word]?.e
        }
        if let word = quoted(in: prompt, after: "How do you say") {
            return byEnglish[word]?.a
        }
        if let word = quoted(in: prompt, after: "Translate:") {
            // The direction is whichever side the word was found on.
            if let entry = byAlbanian[word] { return entry.e }
            if let entry = byEnglish[word] { return entry.a }
            return nil
        }
        if let translation = doubleQuoted(in: prompt) {
            // "Arrange the words to say: "<translation>""
            return byTranslation[translation]?.s
        }
        if let translation = parenthesised(in: prompt) {
            // A cloze prompt ends with its translation in parentheses.
            return byTranslation[translation]?.a
        }
        return nil
    }

    /// The engine's `shortGloss`: the part before any "/" or "(", trimmed.
    /// Mirrored here because a match tile shows the gloss, not the full entry.
    static func shortGloss(_ english: String) -> String {
        let head = english.components(separatedBy: "/").first ?? english
        let noParen = head.components(separatedBy: "(").first ?? head
        let trimmed = noParen.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? english : trimmed
    }

    /// Pulls `'like this'` out of a prompt following a known lead-in.
    private func quoted(in prompt: String, after lead: String) -> String? {
        guard prompt.hasPrefix(lead) else { return nil }
        let parts = prompt.components(separatedBy: "'")
        guard parts.count >= 3 else { return nil }
        return parts[1]
    }

    private func doubleQuoted(in prompt: String) -> String? {
        let parts = prompt.components(separatedBy: "\"")
        guard parts.count >= 3 else { return nil }
        return parts[1]
    }

    private func parenthesised(in prompt: String) -> String? {
        guard let open = prompt.lastIndex(of: "("),
              let close = prompt.lastIndex(of: ")"),
              open < close else { return nil }
        return String(prompt[prompt.index(after: open)..<close])
    }
}
