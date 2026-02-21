import SwiftUI
import ComposableArchitecture

struct VocabularyView: View {
    @Bindable var store: StoreOf<VocabularyFeature>

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $store.searchQuery)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            CEFRFilterBar(selected: store.selectedCEFR) { level in
                store.send(.cefrFilterTapped(level))
            }

            if store.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                List(store.filteredWords) { word in
                    WordRowView(word: word)
                        .listRowBackground(Color.gjuha.surface)
                        .listRowSeparatorTint(Color.gjuha.border)
                }
                .listStyle(.plain)
                .background(Color.gjuha.background)
            }
        }
        .background(Color.gjuha.background)
        .navigationTitle("Vocabulary")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { store.send(.onAppear) }
    }
}

private struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.gjuha.textSecondary)
            TextField("Search words...", text: $text)
                .font(.gjuha.bodyRegular)
        }
        .padding(12)
        .background(Color.gjuha.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct CEFRFilterBar: View {
    let selected: CEFRLevel?
    let onSelect: (CEFRLevel?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: selected == nil) {
                    onSelect(nil)
                }
                ForEach(CEFRLevel.allCases, id: \.self) { level in
                    FilterChip(label: level.rawValue.uppercased(), isSelected: selected == level) {
                        onSelect(level)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.gjuha.caption)
                .foregroundStyle(isSelected ? .white : Color.gjuha.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.gjuha.accent : Color.gjuha.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

private struct WordRowView: View {
    let word: Word

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(word.albanian)
                    .font(.gjuha.labelBold)
                    .foregroundStyle(Color.gjuha.textPrimary)
                Text(word.english)
                    .font(.gjuha.bodyRegular)
                    .foregroundStyle(Color.gjuha.textSecondary)
                if let example = word.exampleSentence {
                    Text(example)
                        .font(.gjuha.caption)
                        .foregroundStyle(Color.gjuha.textTertiary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Text(word.cefrLevel.rawValue.uppercased())
                .font(.gjuha.caption)
                .foregroundStyle(Color.gjuha.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gjuha.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.vertical, 4)
    }
}
