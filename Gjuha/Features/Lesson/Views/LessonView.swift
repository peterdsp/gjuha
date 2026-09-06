import SwiftUI
import ComposableArchitecture

struct LessonView: View {
    let store: StoreOf<LessonFeature>

    var body: some View {
        ZStack {
            GjuhaLiquidGlassBackground()

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
                LessonCompletedView(xp: xp, combo: store.combo, onContinue: { store.send(.exitTapped) })
            case .failed:
                LessonFailedView(onRetry: { store.send(.onAppear) }, onExit: { store.send(.exitTapped) })
            }
        }
        .navigationBarHidden(true)
        .onAppear { store.send(.onAppear) }
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
                    onExit: { store.send(.exitTapped) }
                )

                if let exercise = store.currentExercise {
                    ExerciseView(
                        exercise: exercise,
                        answerResult: store.answerResult,
                        selectedAnswer: store.selectedAnswer,
                        onAnswer: { answer in
                            store.send(.answerSubmitted(answer))
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(exercise.id)
                }
            }
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
                    .foregroundStyle(.white)
                    .scaleEffect(scale)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.gjuha.labelBold)
                        .foregroundStyle(.white)

                    if let answerLine {
                        Text(answerLine)
                            .font(.gjuha.caption)
                            .foregroundStyle(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                if case let .correct(xpAwarded, _) = result {
                    Text("+\(xpAwarded) XP")
                        .font(.gjuha.labelBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            if let explanation = result.explanation, !explanation.isEmpty {
                Text(explanation)
                    .font(.gjuha.caption)
                    .foregroundStyle(.white.opacity(0.92))
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

    private var title: String {
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

    private var answerLine: String? {
        switch result {
        case .correct:
            return nil
        case let .nearMiss(correctAnswer, _), let .wrong(correctAnswer, _):
            return "Answer: \(correctAnswer)"
        }
    }

    /// Full spoken description, independent of colour and haptics.
    private var accessibilityMessage: String {
        var parts: [String] = [title]
        if let answerLine { parts.append(answerLine) }
        if case let .correct(xpAwarded, _) = result { parts.append("\(xpAwarded) XP earned") }
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
                    .foregroundStyle(Color.gjuha.xp)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("\(combo) correct in a row")
            }

            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < hearts ? "heart.fill" : "heart")
                        .foregroundStyle(i < hearts ? Color.gjuha.error : Color.gjuha.textTertiary)
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
        .gjuhaLiquidGlassCard(cornerRadius: 14, tintOpacity: 0.05)
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
                .buttonStyle(.plain)
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
            return ("checkmark.circle.fill", Color.gjuha.success)
        }
        if option == selectedAnswer {
            return ("xmark.circle.fill", Color.gjuha.error)
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
        guard let result = answerResult, let selected = selectedAnswer else {
            return AnyShapeStyle(.ultraThinMaterial)
        }
        if option == correctAnswer {
            return AnyShapeStyle(Color.gjuha.success.opacity(0.2))
        }
        if option == selected, case .wrong = result {
            return AnyShapeStyle(Color.gjuha.error.opacity(0.2))
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    private func borderColor(for option: String) -> Color {
        guard let result = answerResult, let selected = selectedAnswer else {
            return Color.white.opacity(0.24)
        }
        if option == correctAnswer {
            return Color.gjuha.success
        }
        if option == selected, case .wrong = result {
            return Color.gjuha.error
        }
        return Color.white.opacity(0.24)
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
            return Color.gjuha.success
        }
        if option == selected, case .wrong = result {
            return Color.gjuha.error
        }
        return Color.gjuha.textPrimary.opacity(0.5)
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
                .gjuhaLiquidGlassCard(cornerRadius: 12, tintOpacity: 0.06)
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
                    .font(.gjuha.labelBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        trimmed.isEmpty
                            ? Color.gjuha.textTertiary
                            : Color.gjuha.accent
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(trimmed.isEmpty || answerResult != nil)
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Lesson Completed

private struct LessonCompletedView: View {
    let xp: Int
    let combo: Int
    let onContinue: () -> Void
    @State private var starScale: CGFloat = 0.3
    @State private var showXP = false
    @State private var confettiVisible = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                // Confetti-like circles
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(confettiColor(i))
                        .frame(width: 12, height: 12)
                        .offset(confettiOffset(i))
                        .opacity(confettiVisible ? 1 : 0)
                        .scaleEffect(confettiVisible ? 1.0 : 0.1)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.6).delay(Double(i) * 0.06),
                            value: confettiVisible
                        )
                }

                Image(systemName: "star.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.gjuha.xp)
                    .scaleEffect(starScale)
            }

            VStack(spacing: 8) {
                Text("Lesson Complete!")
                    .font(.gjuha.headingLarge)
                    .foregroundStyle(Color.gjuha.textPrimary)

                Text("+\(xp) XP")
                    .font(.gjuha.displayMedium)
                    .foregroundStyle(Color.gjuha.accent)
                    .opacity(showXP ? 1 : 0)
                    .offset(y: showXP ? 0 : 20)

                if combo >= 3 {
                    Text("Best combo: \(combo)x")
                        .font(.gjuha.captionBold)
                        .foregroundStyle(Color.gjuha.xp)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.gjuha.xp.opacity(0.15))
                        .clipShape(Capsule())
                        .opacity(showXP ? 1 : 0)
                }
            }

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.gjuha.accent, Color.gjuha.streak.opacity(0.94)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                starScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                showXP = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.15)) {
                confettiVisible = true
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
                .foregroundStyle(Color.gjuha.error)
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
                        .font(.gjuha.labelBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.gjuha.accent, Color.gjuha.streak.opacity(0.94)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button(action: onExit) {
                    Text("Back to lessons")
                        .font(.gjuha.labelBold)
                        .foregroundStyle(Color.gjuha.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                heartScale = 1.0
            }
        }
    }
}
