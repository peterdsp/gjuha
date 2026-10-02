import SwiftUI
import ComposableArchitecture

struct GrammarView: View {
    let store: StoreOf<GrammarFeature>

    var body: some View {
        ZStack {
            GjuhaLiquidGlassBackground()

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
        }
        .navigationTitle("Grammar")
        .navigationBarTitleDisplayMode(.large)
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
                            .gjuhaLiquidGlassCard(cornerRadius: 14, tintOpacity: 0.06)
                        }
                        .buttonStyle(.plain)
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
        .gjuhaLiquidGlassCard(cornerRadius: 14, tintOpacity: 0.07)
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
        .gjuhaLiquidGlassCard(cornerRadius: 20, tintOpacity: 0.08)
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
                            Text(example)
                                .font(.gjuha.bodyRegular)
                                .foregroundStyle(Color.gjuha.textSecondary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .gjuhaLiquidGlassCard(cornerRadius: 12, tintOpacity: 0.05)
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
                    .foregroundStyle(Color.gjuha.accent)
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
            .buttonStyle(.plain)
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
                .gjuhaLiquidGlassCard(cornerRadius: 12, tintOpacity: 0.05)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 16)
    }

    private var availabilityLabel: String {
        switch availability {
        case .available:
            return "A tailored AI explanation is available on this device."
        case .unavailable:
            return "Showing offline explanations built from your reviewed lessons."
        }
    }

    private func sourceLabel(_ source: CoachSource) -> String {
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
                        Text(cell)
                            .font(rowIdx == 0 ? .gjuha.labelBold : .gjuha.bodyRegular)
                            .foregroundStyle(rowIdx == 0 ? Color.gjuha.textPrimary : Color.gjuha.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(rowIdx == 0 ? Color.gjuha.surfaceSecondary : Color.gjuha.surface)
                    }
                }
                Divider()
            }
        }
        .gjuhaLiquidGlassCard(cornerRadius: 12, tintOpacity: 0.05)
    }
}
