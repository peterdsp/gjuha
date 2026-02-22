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
        HStack(spacing: 12) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .scaleEffect(scale)

            VStack(alignment: .leading, spacing: 2) {
                Text(isCorrect ? "Correct!" : "Not quite...")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(.white)

                if case .wrong(let correctAnswer) = result {
                    Text("Answer: \(correctAnswer)")
                        .font(.gjuha.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            Spacer()

            if isCorrect {
                Text("+XP")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isCorrect ? Color.gjuha.success : Color.gjuha.error)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale = 1.0
            }
        }
    }

    private var isCorrect: Bool {
        if case .correct = result { return true }
        return false
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

            if combo >= 2 {
                Text("\(combo)x")
                    .font(.gjuha.captionBold)
                    .foregroundStyle(Color.gjuha.xp)
                    .transition(.scale.combined(with: .opacity))
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
                .padding(.horizontal, 24)
                .padding(.top, 32)

            Spacer()

            switch exercise.type {
            case .multipleChoiceTranslate, .fillInBlank, .trueFalse:
                MultipleChoiceAnswers(
                    options: exercise.allOptions,
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
                    options: exercise.allOptions,
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

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(options, id: \.self) { option in
                Button(action: { onSelect(option) }) {
                    Text(option)
                        .font(.gjuha.answerOption)
                        .foregroundStyle(textColor(for: option))
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(backgroundColor(for: option))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(borderColor(for: option), lineWidth: borderWidth(for: option))
                        )
                }
                .buttonStyle(.plain)
                .scaleEffect(selectedAnswer == option ? 0.96 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: selectedAnswer)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
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

    private var borderColor: Color {
        guard let result = answerResult else { return .clear }
        if case .correct = result { return Color.gjuha.success }
        return Color.gjuha.error
    }

    var body: some View {
        VStack(spacing: 16) {
            TextField("Type your answer...", text: $text)
                .font(.gjuha.bodyMedium)
                .padding(16)
                .gjuhaLiquidGlassCard(cornerRadius: 12, tintOpacity: 0.06)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(borderColor, lineWidth: answerResult != nil ? 2.5 : 0)
                )
                .padding(.horizontal, 16)
                .disabled(answerResult != nil)
                .onSubmit { if !text.isEmpty { onSubmit(text) } }

            Button(action: { if !text.isEmpty { onSubmit(text) } }) {
                Text("Check")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        text.isEmpty
                            ? Color.gjuha.textTertiary
                            : Color.gjuha.accent
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(text.isEmpty || answerResult != nil)
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
