import SwiftUI
import ComposableArchitecture

struct GrammarView: View {
    let store: StoreOf<GrammarFeature>

    var body: some View {
        ZStack {
            GjuhaLiquidGlassBackground()

            Group {
                if let topic = store.selectedTopic {
                    GrammarTopicDetailView(topic: topic) {
                        store.send(.backTapped)
                    }
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
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
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

private struct GrammarTopicDetailView: View {
    let topic: GrammarTopic
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
