import SwiftUI
import ComposableArchitecture

struct LessonView: View {
    let store: StoreOf<LessonFeature>

    var body: some View {
        ZStack {
            GjuhaAmbientBackground()

            switch store.phase {
            case .loading:
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading exercises...")
                        .font(.gjuha.caption)
                        .foregroundStyle(Color.gjuha.textSecondary)
                }
            case .inProgress:
                LessonInProgressView(store: store)
            case .completed(let xp):
                LessonCompletedView(
                    xp: xp,
                    bestCombo: store.bestCombo,
                    accuracy: store.accuracy,
                    answeredCount: store.answeredCount,
                    isReview: store.isReview,
                    newAchievements: store.newAchievements,
                    metDailyGoal: store.metDailyGoalThisSession,
                    stats: store.statsAfterSession,
                    onContinue: { store.send(.exitTapped) }
                )
            case .failed:
                LessonFailedView(onRetry: { store.send(.onAppear) }, onExit: { store.send(.exitTapped) })
            }
        }
        .navigationBarHidden(true)
        // Haptics for the two moments that carry weight: grading an answer, and
        // finishing or failing the lesson. `sensoryFeedback` is the right tool
        // rather than calling UIFeedbackGenerator directly: it honours the
        // system haptics setting and is a no-op on hardware without a Taptic
        // Engine, so there is nothing to gate by hand.
        //
        // The feedback mirrors the banner exactly, including the near miss, so a
        // learner who feels "warning" rather than "error" knows their spelling
        // was close before they read anything.
        .sensoryFeedback(trigger: store.answerResult) { _, result in
            switch result {
            case .correct: .success
            case .nearMiss: .warning
            case .wrong: .error
            case nil: nil
            }
        }
        .sensoryFeedback(trigger: store.phase) { _, phase in
            switch phase {
            case .completed: .success
            case .failed: .error
            case .loading, .inProgress: nil
            }
        }
        .onAppear { store.send(.onAppear) }
        .alert(
            "Quit lesson?",
            isPresented: Binding(
                get: { store.showExitConfirmation },
                set: { if !$0 { store.send(.exitConfirmationDismissed) } }
            )
        ) {
            Button("Keep learning", role: .cancel) { store.send(.exitConfirmationDismissed) }
            Button("Quit", role: .destructive) { store.send(.exitTapped) }
        } message: {
            Text("Your progress in this lesson will not be saved. You can start it again any time.")
        }
    }
}

private struct LessonInProgressView: View {
    let store: StoreOf<LessonFeature>

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                LessonProgressBar(
                    progress: store.progress,
                    hearts: store.hearts,
                    combo: store.combo,
                    onExit: { store.send(.exitButtonTapped) }
                )

                if let exercise = store.currentExercise {
                    ExerciseView(
                        exercise: exercise,
                        answerResult: store.answerResult,
                        selectedAnswer: store.selectedAnswer,
                        onAnswer: { answer in
                            store.send(.answerSubmitted(answer))
                        },
                        onPlayAudio: { store.send(.playAudioTapped) }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(exercise.id)
                }
            }
            .gjuhaReadableWidth()
            .animation(.easeInOut(duration: 0.25), value: store.currentIndex)

            // Feedback overlay
            if let result = store.answerResult {
                VStack {
                    Spacer()
                    AnswerFeedbackBanner(result: result)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.answerResult)
            }
        }
    }
}

// MARK: - Answer Feedback Banner

private struct AnswerFeedbackBanner: View {
    let result: AnswerResult
    @State private var scale: CGFloat = 0.8

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(bannerForeground)
                    .scaleEffect(scale)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.gjuha.labelBold)
                        .foregroundStyle(bannerForeground)

                    if let answerLine {
                        Text(answerLine)
                            .font(.gjuha.caption)
                            .foregroundStyle(bannerForeground.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                if case let .correct(xpAwarded, _) = result {
                    Text("+\(xpAwarded) XP")
                        .font(.gjuha.labelBold)
                        .foregroundStyle(bannerForeground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(bannerForeground.opacity(0.18))
                        .clipShape(Capsule())
                }
            }

            if let explanation = result.explanation, !explanation.isEmpty {
                Text(explanation)
                    .font(.gjuha.caption)
                    .foregroundStyle(bannerForeground.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(bannerColor)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityMessage)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale = 1.0
            }
            // Announce the outcome for VoiceOver, since the banner auto-dismisses.
            AccessibilityNotification.Announcement(accessibilityMessage).post()
        }
    }

    private var iconName: String {
        switch result {
        case .correct: return "checkmark.circle.fill"
        case .nearMiss: return "exclamationmark.triangle.fill"
        case .wrong: return "xmark.circle.fill"
        }
    }

    /// `LocalizedStringResource` rather than `LocalizedStringKey`, because this
    /// is rendered as a `Text` *and* resolved into the VoiceOver announcement
    /// below, which needs a real `String`.
    private var title: LocalizedStringResource {
        switch result {
        case .correct: return "Correct!"
        case .nearMiss: return "Almost, check the spelling"
        case .wrong: return "Not quite..."
        }
    }

    private var bannerColor: Color {
        switch result {
        case .correct: return Color.gjuha.success
        case .nearMiss: return Color.gjuha.warning
        case .wrong: return Color.gjuha.error
        }
    }

    /// The foreground that is legible on `bannerColor`.
    ///
    /// This was a flat `.white` for all three states. On the amber near-miss
    /// banner white measured 1.76:1, so the line that tells the learner what
    /// they got wrong was the hardest line in the app to read. `warning` keeps
    /// its amber and takes the dark foreground; the other two keep white.
    private var bannerForeground: Color {
        switch result {
        case .nearMiss: return Color.gjuha.onWarning
        case .correct, .wrong: return Color.gjuha.onAccent
        }
    }

    private var answerLine: LocalizedStringResource? {
        switch result {
        case .correct:
            return nil
        case let .nearMiss(correctAnswer, _), let .wrong(correctAnswer, _):
            // The answer itself is Albanian course content; only the label
            // around it is translated.
            return "Answer: \(correctAnswer)"
        }
    }

    /// Full spoken description, independent of colour and haptics.
    private var accessibilityMessage: String {
        // Resolved to concrete strings here: AccessibilityNotification takes a
        // String, so the localized values have to be materialised rather than
        // handed over as resources.
        var parts: [String] = [String(localized: title)]
        if let answerLine { parts.append(String(localized: answerLine)) }
        if case let .correct(xpAwarded, _) = result {
            parts.append(String(localized: "\(xpAwarded) XP earned"))
        }
        if let explanation = result.explanation, !explanation.isEmpty { parts.append(explanation) }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Progress Bar

private struct LessonProgressBar: View {
    let progress: Double
    let hearts: Int
    let combo: Int
    let onExit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onExit) {
                Image(systemName: "xmark")
                    .foregroundStyle(Color.gjuha.textSecondary)
                    .font(.body.weight(.semibold))
                    // A bare 17pt glyph is roughly 17x17pt to touch, well under
                    // the 28x28pt minimum, on the one control that gets a learner
                    // out of a lesson.
                    .gjuhaMinimumHitTarget()
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Exit lesson")

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gjuha.surfaceSecondary)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.gjuha.accent, Color.gjuha.streak],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 12)
            .animation(.spring(response: 0.4), value: progress)
            .accessibilityElement()
            .accessibilityLabel("Lesson progress")
            .accessibilityValue("\(Int((progress * 100).rounded())) percent")

            if combo >= 2 {
                Text("\(combo)x")
                    .font(.gjuha.captionBold)
                    .foregroundStyle(Color.gjuha.xpStrong)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("\(combo) correct in a row")
            }

            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < hearts ? "heart.fill" : "heart")
                        .foregroundStyle(i < hearts ? Color.gjuha.errorStrong : Color.gjuha.textTertiary)
                        .font(.caption)
                        .scaleEffect(i < hearts ? 1.0 : 0.85)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: hearts)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Hearts remaining")
            .accessibilityValue("\(hearts) of 3")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .gjuhaCardSurface(cornerRadius: 14, prominence: .nested)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.2), value: combo)
    }
}

// MARK: - Exercise View

private struct ExerciseView: View {
    let exercise: Exercise
    let answerResult: AnswerResult?
    let selectedAnswer: String?
    let onAnswer: (String) -> Void
    let onPlayAudio: () -> Void

    private var isDisabled: Bool {
        answerResult != nil
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(exercise.prompt)
                .font(.gjuha.exercisePrompt)
                .foregroundStyle(Color.gjuha.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            switch exercise.type {
            case .multipleChoiceTranslate, .fillInBlank, .trueFalse:
                MultipleChoiceAnswers(
                    options: exercise.orderedOptions,
                    correctAnswer: exercise.correctAnswer,
                    selectedAnswer: selectedAnswer,
                    answerResult: answerResult,
                    onSelect: onAnswer
                )
            case .translateTextInput:
                TextInputAnswer(
                    answerResult: answerResult,
                    onSubmit: onAnswer
                )
            case .arrangeWords:
                ArrangeWordsAnswer(
                    tokens: exercise.orderedOptions,
                    answerResult: answerResult,
                    onSubmit: onAnswer
                )
            case .wordMatch:
                WordMatchAnswer(
                    pairs: exercise.pairs,
                    answerResult: answerResult,
                    onComplete: onAnswer
                )
            case .tapWhatYouHear:
                ListeningAnswer(
                    options: exercise.orderedOptions,
                    correctAnswer: exercise.correctAnswer,
                    selectedAnswer: selectedAnswer,
                    answerResult: answerResult,
                    onPlay: onPlayAudio,
                    onSelect: onAnswer
                )
            default:
                MultipleChoiceAnswers(
                    options: exercise.orderedOptions,
                    correctAnswer: exercise.correctAnswer,
                    selectedAnswer: selectedAnswer,
                    answerResult: answerResult,
                    onSelect: onAnswer
                )
            }
        }
        .allowsHitTesting(!isDisabled)
    }
}

// MARK: - Multiple Choice with Feedback

private struct MultipleChoiceAnswers: View {
    let options: [String]
    let correctAnswer: String
    let selectedAnswer: String?
    let answerResult: AnswerResult?
    let onSelect: (String) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Collapse to a single column at accessibility text sizes so long options
    /// stay readable instead of truncating in a cramped two-column grid.
    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(options, id: \.self) { option in
                Button(action: { onSelect(option) }) {
                    Text(option)
                        .font(.gjuha.answerOption)
                        .foregroundStyle(textColor(for: option))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                        .background(backgroundColor(for: option))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(borderColor(for: option), lineWidth: borderWidth(for: option))
                        )
                        .overlay(alignment: .topTrailing) {
                            if let symbol = statusSymbol(for: option) {
                                Image(systemName: symbol.name)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(symbol.color)
                                    .padding(6)
                                    .accessibilityHidden(true)
                            }
                        }
                }
                .buttonStyle(.gjuhaCard)
                .scaleEffect(selectedAnswer == option ? 0.96 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: selectedAnswer)
                .accessibilityLabel(option)
                .accessibilityValue(accessibilityValue(for: option))
                .accessibilityAddTraits(option == selectedAnswer ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
    }

    /// Non-color status marker (checkmark / cross) shown once an answer is graded.
    private func statusSymbol(for option: String) -> (name: String, color: Color)? {
        guard answerResult != nil else { return nil }
        if option == correctAnswer {
            return ("checkmark.circle.fill", Color.gjuha.successStrong)
        }
        if option == selectedAnswer {
            return ("xmark.circle.fill", Color.gjuha.errorStrong)
        }
        return nil
    }

    private func accessibilityValue(for option: String) -> String {
        guard answerResult != nil else { return "" }
        if option == correctAnswer { return "correct answer" }
        if option == selectedAnswer { return "your answer, incorrect" }
        return ""
    }

    private func backgroundColor(for option: String) -> some ShapeStyle {
        let resting = GjuhaSurfaceStyle.restingControlFill(reduceTransparency: reduceTransparency)
        guard let result = answerResult, let selected = selectedAnswer else {
            return resting
        }
        if option == correctAnswer {
            return AnyShapeStyle(Color.gjuha.success.opacity(0.2))
        }
        if option == selected, case .wrong = result {
            return AnyShapeStyle(Color.gjuha.error.opacity(0.2))
        }
        return resting
    }

    private func borderColor(for option: String) -> Color {
        // The resting border was `Color.white.opacity(0.24)` over
        // `.ultraThinMaterial`: in light appearance a tappable answer option had
        // no visible edge, so nothing marked it as a control.
        guard let result = answerResult, let selected = selectedAnswer else {
            return Color.gjuha.hairline
        }
        if option == correctAnswer {
            return Color.gjuha.successStrong
        }
        if option == selected, case .wrong = result {
            return Color.gjuha.errorStrong
        }
        return Color.gjuha.hairline
    }

    private func borderWidth(for option: String) -> CGFloat {
        guard let _ = answerResult, let selected = selectedAnswer else { return 0.8 }
        if option == correctAnswer || option == selected { return 2.5 }
        return 0.8
    }

    private func textColor(for option: String) -> Color {
        guard let result = answerResult, let selected = selectedAnswer else {
            return Color.gjuha.textPrimary
        }
        if option == correctAnswer {
            return Color.gjuha.successStrong
        }
        if option == selected, case .wrong = result {
            return Color.gjuha.errorStrong
        }
        // `textSecondary` rather than primary at 50%: a half-transparent label
        // over a material measures below the text floor, a token does not.
        return Color.gjuha.textSecondary
    }
}

// MARK: - Text Input with Feedback

private struct TextInputAnswer: View {
    let answerResult: AnswerResult?
    let onSubmit: (String) -> Void
    @State private var text = ""

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var borderColor: Color {
        switch answerResult {
        case .correct: return Color.gjuha.success
        case .nearMiss: return Color.gjuha.warning
        case .wrong: return Color.gjuha.error
        case .none: return .clear
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            TextField("Type your answer...", text: $text)
                .font(.gjuha.bodyMedium)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.done)
                .padding(16)
                .gjuhaCardSurface(cornerRadius: 12, prominence: .nested)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(borderColor, lineWidth: answerResult != nil ? 2.5 : 0)
                )
                .padding(.horizontal, 16)
                .disabled(answerResult != nil)
                .accessibilityLabel("Answer")
                .accessibilityHint("Type your translation, then submit")
                .onSubmit { if !trimmed.isEmpty { onSubmit(trimmed) } }

            Button(action: { if !trimmed.isEmpty { onSubmit(trimmed) } }) {
                Text("Check")
            }
            .buttonStyle(.gjuhaPrimary)
            .disabled(trimmed.isEmpty || answerResult != nil)
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Flow Layout (wrapping chips)

/// A simple wrapping layout: lays subviews left to right, moving to a new line
/// when the next subview would overflow. Used by the word-order and matching
/// exercises where chip widths vary.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxLine: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                maxLine = max(maxLine, x - spacing)
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        maxLine = max(maxLine, x - spacing)
        let width = proposal.width ?? max(maxLine, 0)
        return CGSize(width: width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

private struct ChipLabel: View {
    let text: String
    var muted: Bool = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Text(text)
            .font(.gjuha.answerOption)
            .foregroundStyle(muted ? Color.gjuha.textTertiary : Color.gjuha.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(GjuhaSurfaceStyle.restingControlFill(reduceTransparency: reduceTransparency))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.gjuha.hairline, lineWidth: 0.8)
            )
    }
}

// MARK: - Word Ordering

private struct ArrangeWordsAnswer: View {
    let tokens: [String]
    let answerResult: AnswerResult?
    let onSubmit: (String) -> Void

    /// Indices into `tokens`, in the order the learner placed them.
    @State private var placed: [Int] = []

    private var remaining: [Int] { tokens.indices.filter { !placed.contains($0) } }
    private var sentence: String { placed.map { tokens[$0] }.joined(separator: " ") }
    private var isGraded: Bool { answerResult != nil }

    var body: some View {
        VStack(spacing: 20) {
            // Assembled sentence
            FlowLayout(spacing: 8) {
                ForEach(placed, id: \.self) { index in
                    Button { if !isGraded { placed.removeAll { $0 == index } } } label: {
                        ChipLabel(text: tokens[index])
                    }
                    .buttonStyle(.gjuhaCard)
                    .accessibilityLabel("Placed word \(tokens[index]), tap to remove")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .padding(12)
            .frame(maxWidth: .infinity)
            .gjuhaCardSurface(cornerRadius: 12, prominence: .nested)
            .padding(.horizontal, 16)

            // Word bank
            FlowLayout(spacing: 8) {
                ForEach(remaining, id: \.self) { index in
                    Button { if !isGraded { placed.append(index) } } label: {
                        ChipLabel(text: tokens[index])
                    }
                    .buttonStyle(.gjuhaCard)
                    .accessibilityLabel("Word \(tokens[index]), tap to add")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)

            Button {
                onSubmit(sentence)
            } label: {
                Text("Check")
            }
            .buttonStyle(.gjuhaPrimary)
            .disabled(placed.isEmpty || isGraded)
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Matching

private struct WordMatchAnswer: View {
    let pairs: [MatchPair]
    let answerResult: AnswerResult?
    let onComplete: (String) -> Void

    @State private var leftOrder: [Int] = []
    @State private var rightOrder: [Int] = []
    @State private var selectedLeft: Int?
    @State private var matched: Set<Int> = []
    @State private var wrongFlash: Int?
    @State private var didSetup = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            column(order: leftOrder, isLeft: true)
            column(order: rightOrder, isLeft: false)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
        .onAppear(perform: setup)
    }

    private func column(order: [Int], isLeft: Bool) -> some View {
        VStack(spacing: 10) {
            ForEach(order, id: \.self) { pairIndex in
                let text = isLeft ? pairs[pairIndex].albanian : pairs[pairIndex].english
                Button { tap(pairIndex, isLeft: isLeft) } label: {
                    Text(text)
                        .font(.gjuha.answerOption)
                        .foregroundStyle(foreground(pairIndex, isLeft: isLeft))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .padding(.horizontal, 8)
                        .background(background(pairIndex, isLeft: isLeft))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(border(pairIndex, isLeft: isLeft), lineWidth: 2)
                        )
                }
                .buttonStyle(.gjuhaCard)
                .disabled(matched.contains(pairIndex))
                .accessibilityLabel(text)
                .accessibilityValue(matched.contains(pairIndex) ? "matched" : "not matched")
            }
        }
    }

    private func setup() {
        guard !didSetup else { return }
        leftOrder = Array(pairs.indices).shuffled()
        rightOrder = Array(pairs.indices).shuffled()
        didSetup = true
    }

    private func tap(_ pairIndex: Int, isLeft: Bool) {
        guard answerResult == nil, !matched.contains(pairIndex) else { return }
        if isLeft {
            selectedLeft = (selectedLeft == pairIndex) ? nil : pairIndex
            return
        }
        guard let left = selectedLeft else { return }
        if left == pairIndex {
            matched.insert(pairIndex)
            selectedLeft = nil
            if matched.count == pairs.count {
                onComplete(Exercise.matchAnswer(from: pairs))
            }
        } else {
            // Wrong connection: flash, keep the board, let the learner retry.
            wrongFlash = pairIndex
            selectedLeft = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if wrongFlash == pairIndex { wrongFlash = nil }
            }
        }
    }

    private func foreground(_ i: Int, isLeft: Bool) -> Color {
        if matched.contains(i) { return Color.gjuha.successStrong }
        return Color.gjuha.textPrimary
    }

    private func background(_ i: Int, isLeft: Bool) -> some ShapeStyle {
        if matched.contains(i) { return AnyShapeStyle(Color.gjuha.success.opacity(0.18)) }
        if wrongFlash == i, !isLeft { return AnyShapeStyle(Color.gjuha.error.opacity(0.18)) }
        return GjuhaSurfaceStyle.restingControlFill(reduceTransparency: reduceTransparency)
    }

    private func border(_ i: Int, isLeft: Bool) -> Color {
        if matched.contains(i) { return Color.gjuha.successStrong }
        if wrongFlash == i, !isLeft { return Color.gjuha.errorStrong }
        if isLeft, selectedLeft == i { return Color.gjuha.accentStrong }
        return Color.gjuha.hairline
    }
}

// MARK: - Listening

private struct ListeningAnswer: View {
    let options: [String]
    let correctAnswer: String
    let selectedAnswer: String?
    let answerResult: AnswerResult?
    let onPlay: () -> Void
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Button(action: onPlay) {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.gjuha.onAccent)
                    .frame(width: 96, height: 96)
                    .background(
                        LinearGradient(
                            colors: [Color.gjuha.accent, Color.gjuha.streak],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.gjuhaCard)
            .accessibilityLabel("Play audio")
            .accessibilityHint("Plays the word to identify")

            MultipleChoiceAnswers(
                options: options,
                correctAnswer: correctAnswer,
                selectedAnswer: selectedAnswer,
                answerResult: answerResult,
                onSelect: onSelect
            )
        }
        .onAppear(perform: onPlay)
    }
}

// MARK: - Lesson Completed

private struct LessonCompletedView: View {
    let xp: Int
    let bestCombo: Int
    /// Nil when there is nothing to report: a session resumed from a snapshot
    /// written before the counters existed. Omitted rather than shown as 0%.
    let accuracy: Double?
    let answeredCount: Int
    let isReview: Bool
    let newAchievements: [Achievement]
    let metDailyGoal: Bool
    let stats: UserStats?
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var starScale: CGFloat = 0.3
    @State private var showDetail = false
    @State private var confettiVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: .gjuha.loose) {
                celebration

                VStack(spacing: .gjuha.tight) {
                    Text(isReview ? "Review complete!" : "Lesson complete!")
                        .font(.gjuha.headingLarge)
                        .foregroundStyle(Color.gjuha.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("+\(xp) XP")
                        .font(.gjuha.displayMedium)
                        .foregroundStyle(Color.gjuha.accentStrong)
                        .opacity(showDetail ? 1 : 0)
                        .offset(y: showDetail ? 0 : 20)
                }

                summaryTiles
                    .opacity(showDetail ? 1 : 0)

                if metDailyGoal {
                    DailyGoalMetBanner()
                        .opacity(showDetail ? 1 : 0)
                }

                if !newAchievements.isEmpty {
                    UnlockedAchievementsCard(achievements: newAchievements)
                        .opacity(showDetail ? 1 : 0)
                }
            }
            .padding(.horizontal, .gjuha.loose)
            .padding(.top, .gjuha.section)
            .padding(.bottom, .gjuha.regular)
            .gjuhaReadableWidth()
        }
        // The screen used two `Spacer()`s around fixed content, so at larger
        // Dynamic Type sizes, or with an achievement card present, the Continue
        // button was pushed off the bottom with no way to reach it. A scroll view
        // with the action pinned below keeps the button reachable at every text
        // size.
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                Text("Continue")
            }
            .buttonStyle(.gjuhaPrimary)
            .padding(.horizontal, .gjuha.loose)
            .padding(.bottom, .gjuha.loose)
            .background(GjuhaSurfaceStyle.floatingBarFill(reduceTransparency: reduceTransparency))
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                starScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                showDetail = true
            }
            if !reduceMotion {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.15)) {
                    confettiVisible = true
                }
            } else {
                confettiVisible = true
            }
        }
    }

    // MARK: Celebration

    private var celebration: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(confettiColor(i))
                    .frame(width: 12, height: 12)
                    .offset(confettiOffset(i))
                    .opacity(confettiVisible ? 1 : 0)
                    .scaleEffect(confettiVisible ? 1.0 : 0.1)
                    .animation(
                        reduceMotion
                        ? .linear(duration: 0.01)
                        : .spring(response: 0.5, dampingFraction: 0.6).delay(Double(i) * 0.06),
                        value: confettiVisible
                    )
            }

            Image(systemName: "star.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.gjuha.xpStrong)
                .scaleEffect(starScale)
        }
        .frame(height: 150)
        .accessibilityHidden(true)
    }

    // MARK: Summary

    /// What the session actually produced. The screen previously showed XP and a
    /// "best combo" that was really `combo` at the final question, so a learner
    /// who slipped on the last answer was told their best combo was 0.
    @ViewBuilder
    private var summaryTiles: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        LazyVGrid(columns: columns, spacing: .gjuha.snug) {
            if let accuracy {
                SessionStatTile(
                    icon: "target",
                    value: accuracy.formatted(.percent.precision(.fractionLength(0))),
                    label: "Accuracy",
                    tint: accuracy >= 0.8 ? Color.gjuha.successStrong : Color.gjuha.accentStrong
                )
            }

            SessionStatTile(
                icon: "list.number",
                value: answeredCount.formatted(),
                label: isReview ? "Words reviewed" : "Questions",
                tint: Color.gjuha.accentStrong
            )

            if bestCombo >= 2 {
                SessionStatTile(
                    icon: "bolt.fill",
                    value: "\(bestCombo)x",
                    label: "Best streak",
                    tint: Color.gjuha.xpStrong
                )
            }

            if let stats {
                SessionStatTile(
                    icon: "flame.fill",
                    value: stats.currentStreak.formatted(),
                    label: "Day streak",
                    tint: Color.gjuha.streakStrong
                )
            }
        }
    }

    private func confettiColor(_ index: Int) -> Color {
        let colors: [Color] = [.gjuha.accent, .gjuha.xp, .gjuha.streak, .gjuha.success]
        return colors[index % colors.count]
    }

    private func confettiOffset(_ index: Int) -> CGSize {
        let angle = (Double(index) / 8.0) * 2.0 * .pi
        let radius: CGFloat = 70
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
    }
}

// MARK: - Session Stat Tile

private struct SessionStatTile: View {
    let icon: String
    let value: String
    /// `LocalizedStringKey`, so the label reaches the String Catalog.
    let label: LocalizedStringKey
    let tint: Color

    var body: some View {
        VStack(spacing: .gjuha.hairline) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.gjuha.headingMedium)
                .foregroundStyle(Color.gjuha.textPrimary)
            Text(label)
                .font(.gjuha.caption)
                .foregroundStyle(Color.gjuha.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.gjuha.snug)
        .gjuhaCardSurface(cornerRadius: GjuhaSpacing.Radius.medium, prominence: .nested)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

// MARK: - Daily Goal Met

private struct DailyGoalMetBanner: View {
    var body: some View {
        HStack(spacing: .gjuha.snug) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.gjuha.onAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Daily goal met")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(Color.gjuha.onAccent)
                Text("Your streak is safe for today.")
                    .font(.gjuha.caption)
                    .foregroundStyle(Color.gjuha.onAccent.opacity(0.92))
            }

            Spacer(minLength: 0)
        }
        .padding(.gjuha.regular)
        .background(Color.gjuha.success)
        .clipShape(RoundedRectangle(cornerRadius: GjuhaSpacing.Radius.large, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Unlocked Achievements

private struct UnlockedAchievementsCard: View {
    let achievements: [Achievement]

    var body: some View {
        VStack(alignment: .leading, spacing: .gjuha.snug) {
            Text(achievements.count == 1 ? "New achievement" : "New achievements")
                .font(.gjuha.headingSmall)
                .foregroundStyle(Color.gjuha.textPrimary)

            ForEach(achievements) { achievement in
                HStack(spacing: .gjuha.snug) {
                    Image(systemName: achievement.symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.gjuha.onWarning)
                        .frame(width: 40, height: 40)
                        .background(Color.gjuha.xp)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(achievement.title)
                            .font(.gjuha.labelBold)
                            .foregroundStyle(Color.gjuha.textPrimary)
                        Text(achievement.detail)
                            .font(.gjuha.caption)
                            .foregroundStyle(Color.gjuha.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.gjuha.regular)
        .gjuhaCardSurface(cornerRadius: GjuhaSpacing.Radius.large, prominence: .standard)
    }
}

// MARK: - Lesson Failed

private struct LessonFailedView: View {
    let onRetry: () -> Void
    let onExit: () -> Void
    @State private var heartScale: CGFloat = 0.5

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.gjuha.errorStrong)
                .scaleEffect(heartScale)

            VStack(spacing: 8) {
                Text("Out of hearts!")
                    .font(.gjuha.headingLarge)
                    .foregroundStyle(Color.gjuha.textPrimary)
                Text("Practice more to strengthen your memory.")
                    .font(.gjuha.bodyRegular)
                    .foregroundStyle(Color.gjuha.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            VStack(spacing: 12) {
                Button(action: onRetry) {
                    Text("Try again")
                }
                .buttonStyle(.gjuhaPrimary)

                Button(action: onExit) {
                    Text("Back to lessons")
                }
                .buttonStyle(.gjuhaSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .gjuhaReadableWidth()
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                heartScale = 1.0
            }
        }
    }
}
