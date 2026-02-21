import SwiftUI
import ComposableArchitecture

struct GrammarView: View {
    let store: StoreOf<GrammarFeature>

    var body: some View {
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
        } else {
            List(topics) { topic in
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
                }
                .listRowBackground(Color.gjuha.surface)
            }
            .listStyle(.plain)
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
                                .background(Color.gjuha.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 16)
        }
        .background(Color.gjuha.background)
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
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gjuha.border, lineWidth: 1))
    }
}
