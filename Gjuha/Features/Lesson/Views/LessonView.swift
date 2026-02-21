import SwiftUI
import ComposableArchitecture

struct LessonView: View {
    let store: StoreOf<LessonFeature>

    var body: some View {
        ZStack {
            Color.gjuha.background.ignoresSafeArea()

            switch store.phase {
            case .loading:
                ProgressView()
            case .inProgress:
                LessonInProgressView(store: store)
            case .completed(let xp):
                LessonCompletedView(xp: xp, onContinue: { store.send(.exitTapped) })
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
        VStack(spacing: 0) {
            LessonProgressBar(
                progress: store.progress,
                hearts: store.hearts,
                onExit: { store.send(.exitTapped) }
            )

            if let exercise = store.currentExercise {
                ExerciseView(exercise: exercise) { answer in
                    store.send(.answerSubmitted(answer))
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(exercise.id)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.currentIndex)
    }
}

private struct LessonProgressBar: View {
    let progress: Double
    let hearts: Int
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
                        .fill(Color.gjuha.accent)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 12)
            .animation(.spring(response: 0.4), value: progress)

            HStack(spacing: 2) {
                ForEach(0..<3) { i in
                    Image(systemName: i < hearts ? "heart.fill" : "heart")
                        .foregroundStyle(i < hearts ? Color.gjuha.error : Color.gjuha.textTertiary)
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct ExerciseView: View {
    let exercise: Exercise
    let onAnswer: (String) -> Void

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
                MultipleChoiceAnswers(options: exercise.allOptions, onSelect: onAnswer)
            case .translateTextInput:
                TextInputAnswer(onSubmit: onAnswer)
            default:
                MultipleChoiceAnswers(options: exercise.allOptions, onSelect: onAnswer)
            }
        }
    }
}

private struct MultipleChoiceAnswers: View {
    let options: [String]
    let onSelect: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(options, id: \.self) { option in
                Button(action: { onSelect(option) }) {
                    Text(option)
                        .font(.gjuha.answerOption)
                        .foregroundStyle(Color.gjuha.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(Color.gjuha.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gjuha.border, lineWidth: 1.5)
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
}

private struct TextInputAnswer: View {
    @State private var text = ""
    let onSubmit: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            TextField("Type your answer...", text: $text)
                .font(.gjuha.bodyMedium)
                .padding(16)
                .background(Color.gjuha.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gjuha.border, lineWidth: 1.5))
                .padding(.horizontal, 16)
                .onSubmit { if !text.isEmpty { onSubmit(text) } }

            Button(action: { if !text.isEmpty { onSubmit(text) } }) {
                Text("Check")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(text.isEmpty ? Color.gjuha.textTertiary : Color.gjuha.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(text.isEmpty)
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }
}

private struct LessonCompletedView: View {
    let xp: Int
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "star.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.gjuha.xp)

            VStack(spacing: 8) {
                Text("Lesson Complete!")
                    .font(.gjuha.headingLarge)
                    .foregroundStyle(Color.gjuha.textPrimary)
                Text("+\(xp) XP")
                    .font(.gjuha.displayMedium)
                    .foregroundStyle(Color.gjuha.accent)
            }
            Spacer()
            Button(action: onContinue) {
                Text("Continue")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.gjuha.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

private struct LessonFailedView: View {
    let onRetry: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.gjuha.error)

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
                        .background(Color.gjuha.accent)
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
    }
}
