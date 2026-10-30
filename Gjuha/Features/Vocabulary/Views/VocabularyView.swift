import SwiftUI
import ComposableArchitecture

struct VocabularyView: View {
    @Bindable var store: StoreOf<VocabularyFeature>

    var body: some View {
        ZStack {
            GjuhaAmbientBackground()

            VStack(spacing: 0) {
                VocabularyPulseBanner(
                    totalWords: store.words.count,
                    visibleWords: store.filteredWords.count
                )
                .padding(.horizontal, 16)
                .padding(.top, 6)

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
                    if store.filteredWords.isEmpty {
                        VocabularyEmptyStateView(query: store.searchQuery)
                            .padding(.horizontal, 16)
                            .padding(.top, 18)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(store.filteredWords) { word in
                                    WordRowView(
                                        word: word,
                                        canPlay: word.audioFileName != nil || store.canSpeakAlbanian,
                                        onPlay: { store.send(.playPronunciation(word)) }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .gjuhaReadableWidth()
        }
        .gjuhaScreenTitle("Vocabulary")
        .onAppear { store.send(.onAppear) }
    }
}

private struct VocabularyPulseBanner: View {
    let totalWords: Int
    let visibleWords: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            AnimatedMascotView(size: 34, usesGlassOrb: false)
                .scaleEffect(pulse ? 1.08 : 0.92)
                .animation(
                    reduceMotion
                    ? .linear(duration: 0.01)
                    : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                    value: pulse
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Vocabulary Engine")
                    .font(.gjuha.labelBold)
                    .foregroundStyle(Color.gjuha.textPrimary)
                Text("\(visibleWords) shown • \(totalWords) loaded from Albanian seed")
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

private struct VocabularyEmptyStateView: View {
    let query: String

    var body: some View {
        VStack(spacing: 12) {
            AnimatedMascotView(size: 78, usesGlassOrb: false)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 6)

            Text(query.isEmpty ? "Vocabulary is loading" : "No results for \"\(query)\"")
                .font(.gjuha.headingSmall)
                .foregroundStyle(Color.gjuha.textPrimary)

            Text(query.isEmpty ? "The Albanian pack is ready. Pull to refresh or reopen the app." : "Try another spelling or switch CEFR filter.")
                .font(.gjuha.caption)
                .foregroundStyle(Color.gjuha.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .gjuhaCardSurface(cornerRadius: 20, prominence: .standard)
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
        .gjuhaCardSurface(cornerRadius: 14, prominence: .standard)
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
                    // CEFR codes are acronyms, identical in every language, so this one is
                    // built from a runtime string on purpose and is not extracted.
                    FilterChip(label: LocalizedStringKey(level.rawValue.uppercased()), isSelected: selected == level) {
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
    let label: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.gjuha.caption)
                .foregroundStyle(isSelected ? Color.gjuha.onAccent : Color.gjuha.textSecondary)
                .padding(.horizontal, .gjuha.snug)
                .padding(.vertical, .gjuha.tight)
                .background(
                    isSelected
                    ? AnyShapeStyle(Color.gjuha.accent)
                    : GjuhaSurfaceStyle.restingControlFill(reduceTransparency: reduceTransparency)
                )
                .clipShape(Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isSelected ? Color.clear : Color.gjuha.hairline, lineWidth: 0.8)
                )
                // The pill measured about 24pt tall: 12pt caption plus 6pt of
                // padding each side. Apple's default control size on iOS is
                // 44x44pt with 28x28pt the hard minimum, so this was under even
                // the minimum. The frame grows the tappable area without
                // changing how the pill looks.
                .frame(minHeight: GjuhaSpacing.minimumHitTarget)
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.gjuhaCard)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct WordRowView: View {
    let word: Word
    var canPlay: Bool = false
    var onPlay: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility text sizes the CEFR badge and the word column cannot
        // share a line: the badge is pushed to a sliver and the example sentence
        // wraps to four or five lines beside it. Stacking puts the badge under
        // the word instead, which is the same information in the space available.
        let layout: AnyLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: .gjuha.tight))
            : AnyLayout(HStackLayout(alignment: .center, spacing: .gjuha.snug))

        layout {
            if canPlay {
                Button(action: onPlay) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.gjuha.accentStrong)
                        .frame(width: 34, height: 34)
                        .background(Color.gjuha.accent.opacity(0.12))
                        .clipShape(Circle())
                        // The circle is 34pt, under the 44pt default control
                        // size. The frame grows what is tappable without
                        // changing what is drawn.
                        .gjuhaMinimumHitTarget()
                        .contentShape(Circle())
                }
                .buttonStyle(.gjuhaCard)
                .accessibilityLabel("Play pronunciation of \(word.albanian)")
            }

            VStack(alignment: .leading, spacing: .gjuha.hairline) {
                // The Albanian word is the thing being taught, so it is the
                // display element of the row. It was set at 14 points with its
                // English gloss at 16, which put the translation above the
                // language on a screen whose whole purpose is the language.
                //
                // This is also where the art direction lives: at this size the
                // diacritics and the digraphs are shapes rather than specks,
                // which is the point of them being the motif at all.
                Text(word.albanian)
                    .font(.gjuha.headingMedium)
                    .gjuhaDisplayTracking(-0.4)
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
            // One accessibility element for the word itself, so VoiceOver reads
            // "shtëpi, house" and its level as a single item. Before, every row
            // was three or four separate stops, which makes browsing a 350 word
            // list by swipe far slower than it needs to be. The play button stays
            // its own element, because it is a separate action.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(word.albanian)
            .accessibilityValue(accessibilityValue)

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: .gjuha.tight)
            }

            Text(word.cefrLevel.rawValue.uppercased())
                .font(.gjuha.caption)
                .foregroundStyle(Color.gjuha.textSecondary)
                .padding(.horizontal, .gjuha.tight)
                .padding(.vertical, .gjuha.hairline)
                .background(Color.gjuha.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                // Spoken as part of the word above, so it is not a second stop.
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, .gjuha.snug)
        .gjuhaCardSurface(cornerRadius: 14, prominence: .nested)
    }

    /// Translation, level, and the example when there is one, in one spoken line.
    private var accessibilityValue: String {
        var parts = [word.english, word.cefrLevel.rawValue.uppercased()]
        if let example = word.exampleSentence { parts.append(example) }
        return parts.joined(separator: ". ")
    }
}
