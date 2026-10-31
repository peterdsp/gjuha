import SwiftUI
import ComposableArchitecture

struct GrammarView: View {
    let store: StoreOf<GrammarFeature>

    var body: some View {
        ZStack {
            GjuhaAmbientBackground()

            Group {
                if let topic = store.selectedTopic {
                    GrammarTopicDetailView(
                        topic: topic,
                        coachAvailability: store.coach.availability,
                        coachResult: store.coach.result,
                        isCoaching: store.coach.isGenerating,
                        onExplain: { question in
                            store.send(.explainTapped(topic, question: question))
                        },
                        onBack: { store.send(.backTapped) }
                    )
                } else {
                    GrammarTopicListView(
                        topics: store.topics,
                        isLoading: store.isLoading
                    ) { topic in
                        store.send(.topicSelected(topic))
                    }
                }
            }
            .gjuhaReadableWidth()
        }
        .gjuhaScreenTitle("Grammar")
        .onAppear { store.send(.onAppear) }
    }
}

private struct GrammarTopicListView: View {
    let topics: [GrammarTopic]
    let isLoading: Bool
    let onSelect: (GrammarTopic) -> Void

    var body: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if topics.isEmpty {
            GrammarEmptyStateView()
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    GrammarPulseBanner(topicsCount: topics.count)
                        .padding(.bottom, 4)

                    ForEach(topics) { topic in
                        Button(action: { onSelect(topic) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(topic.title)
                                        .font(.gjuha.labelBold)
                                        .foregroundStyle(Color.gjuha.textPrimary)
                                    Text(topic.subtitle)
                                        .font(.gjuha.caption)
                                        .foregroundStyle(Color.gjuha.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.gjuha.textTertiary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .gjuhaCardSurface(cornerRadius: 14, prominence: .nested)
                        }
                        .buttonStyle(.gjuhaCard)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct GrammarPulseBanner: View {
    let topicsCount: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            AnimatedMascotView(size: 34, usesGlassOrb: false)
                .scaleEffect(pulse ? 1.06 : 0.92)
                .animation(
                    reduceMotion
                    ? .linear(duration: 0.01)
                    : .easeInOut(duration: 0.95).repeatForever(autoreverses: true),
                    value: pulse
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Grammar Lab")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(Color.gjuha.textPrimary)
                Text("\(topicsCount) transparent grammar guides available")
                    .font(.gjuha.caption)
                    .foregroundStyle(Color.gjuha.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .gjuhaCardSurface(cornerRadius: 14, prominence: .standard)
        .onAppear {
            if reduceMotion { return }
            pulse = true
        }
    }
}

private struct GrammarEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            AnimatedMascotView(size: 78, usesGlassOrb: false)

            Text("Grammar topics are loading")
                .font(.gjuha.headingSmall)
                .foregroundStyle(Color.gjuha.textPrimary)
            Text("Your Albanian grammar cards will appear here.")
                .font(.gjuha.caption)
                .foregroundStyle(Color.gjuha.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .gjuhaCardSurface(cornerRadius: 20, prominence: .standard)
    }
}

private struct GrammarTopicDetailView: View {
    let topic: GrammarTopic
    let coachAvailability: CoachAvailability
    let coachResult: CoachingResult?
    let isCoaching: Bool
    let onExplain: (String) -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(topic.explanation)
                    .font(.gjuha.bodyRegular)
                    .foregroundStyle(Color.gjuha.textPrimary)
                    .padding(.horizontal, 16)

                if !topic.conjugationTable.isEmpty {
                    ConjugationTableView(table: topic.conjugationTable)
                        .padding(.horizontal, 16)
                }

                if !topic.examples.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Examples")
                            .font(.gjuha.headingMedium)
                            .foregroundStyle(Color.gjuha.textPrimary)

                        ForEach(topic.examples, id: \.self) { example in
                            // Written "Unë jam student. - I am a student."
                            // The Albanian sentence is the example; the English
                            // is there so the learner can check it. They were
                            // the same weight and the same grey.
                            GrammarExample(text: example)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .gjuhaCardSurface(cornerRadius: 12, prominence: .nested)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                GrammarCoachSection(
                    availability: coachAvailability,
                    result: coachResult,
                    isGenerating: isCoaching,
                    onExplain: onExplain
                )
            }
            .padding(.top, 16)
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                    Text("Grammar")
                }
            }
        }
    }
}

/// Grammar coaching panel. Offers an English explanation of the current topic,
/// generated on device when Apple Intelligence is available and grounded in the
/// reviewed lesson notes, with a deterministic offline fallback otherwise. It
/// explains only; it never grades answers.
private struct GrammarCoachSection: View {
    let availability: CoachAvailability
    let result: CoachingResult?
    let isGenerating: Bool
    let onExplain: (String) -> Void

    @State private var question: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.gjuha.accentStrong)
                Text("Explain simply (beta)")
                    .font(.gjuha.headingMedium)
                    .foregroundStyle(Color.gjuha.textPrimary)
                Spacer()
            }

            Text(availabilityLabel)
                .font(.gjuha.caption)
                .foregroundStyle(Color.gjuha.textSecondary)

            TextField("Ask about this topic (optional)", text: $question, axis: .vertical)
                .font(.gjuha.bodyRegular)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
                .disabled(isGenerating)
                .accessibilityLabel("Ask a question about this grammar topic")

            Button {
                onExplain(question)
            } label: {
                HStack(spacing: 8) {
                    if isGenerating { ProgressView() }
                    Text(isGenerating ? "Thinking" : "Explain")
                        .font(.gjuha.labelBold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gjuha.accent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.gjuhaCard)
            .disabled(isGenerating)
            .accessibilityLabel(isGenerating ? "Generating explanation" : "Explain this topic")

            if let result {
                VStack(alignment: .leading, spacing: 8) {
                    Text(sourceLabel(result.source))
                        .font(.gjuha.caption)
                        .foregroundStyle(Color.gjuha.textTertiary)
                    Text(result.text)
                        .font(.gjuha.bodyRegular)
                        .foregroundStyle(Color.gjuha.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(result.disclaimer)
                        .font(.gjuha.caption)
                        .foregroundStyle(Color.gjuha.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .gjuhaCardSurface(cornerRadius: 12, prominence: .nested)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 16)
    }

    private var availabilityLabel: LocalizedStringKey {
        switch availability {
        case .available:
            return "A tailored AI explanation is available on this device."
        case .unavailable:
            return "Showing offline explanations built from your reviewed lessons."
        }
    }

    private func sourceLabel(_ source: CoachSource) -> LocalizedStringKey {
        switch source {
        case .foundationModel: return "AI generated"
        case .deterministicFallback: return "From your reviewed lessons"
        }
    }
}

private struct ConjugationTableView: View {
    let table: [[String]]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(table.enumerated()), id: \.offset) { rowIdx, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIdx, cell in
                        // A body cell is written "jam - I am": the Albanian
                        // form and then what it means. Rendered as one string
                        // the two carried the same weight, so the conjugation
                        // being taught read no louder than its gloss.
                        ConjugationCell(cell: cell, isHeader: rowIdx == 0)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(rowIdx == 0 ? Color.gjuha.surfaceSecondary : Color.gjuha.surface)
                    }
                }
                Divider()
            }
        }
        .gjuhaCardSurface(cornerRadius: 12, prominence: .nested)
    }
}

/// One cell of a conjugation table.
///
/// The seed writes a body cell as "jam - I am". The Albanian form is the thing
/// being taught, so it takes the primary weight and colour and the gloss sits
/// behind it, the same way a vocabulary row treats a word and its meaning. A
/// cell with no gloss, and every header cell, is rendered whole.
private struct ConjugationCell: View {
    let cell: String
    let isHeader: Bool

    private var parts: (form: String, gloss: String?) {
        guard !isHeader, let range = cell.range(of: " - ") else { return (cell, nil) }
        return (String(cell[..<range.lowerBound]), String(cell[range.upperBound...]))
    }

    var body: some View {
        let split = parts
        VStack(alignment: .leading, spacing: 1) {
            Text(split.form)
                .font(isHeader ? .gjuha.labelBold : .gjuha.bodyMedium)
                .foregroundStyle(Color.gjuha.textPrimary)
            if let gloss = split.gloss {
                Text(gloss)
                    .font(.gjuha.caption)
                    .foregroundStyle(Color.gjuha.textSecondary)
            }
        }
    }
}

/// One worked example under a grammar guide.
///
/// The seed writes these as "Albanian. - English.". The Albanian is the
/// example and the English is the check on it, so they are not set alike.
private struct GrammarExample: View {
    let text: String

    var body: some View {
        let parts = text.range(of: " - ").map {
            (String(text[..<$0.lowerBound]), String(text[$0.upperBound...]))
        }
        VStack(alignment: .leading, spacing: 2) {
            Text(parts?.0 ?? text)
                .font(.gjuha.bodyMedium)
                .foregroundStyle(Color.gjuha.textPrimary)
            if let english = parts?.1 {
                Text(english)
                    .font(.gjuha.caption)
                    .foregroundStyle(Color.gjuha.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
