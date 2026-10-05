import SwiftUI
import ComposableArchitecture

// MARK: - Culture hub (list)

struct CultureView: View {
    let store: StoreOf<CultureFeature>

    var body: some View {
        ZStack {
            GjuhaLiquidGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Explore the living language: everyday cultural situations and the regional forms you may hear at home.")
                        .font(.gjuha.bodyRegular)
                        .foregroundStyle(Color.gjuha.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if store.isLoading {
                        ProgressView().padding(.top, 24)
                    } else if store.showsEmptyState {
                        CultureEmptyStateView()
                    } else {
                        if !store.culturalUnits.isEmpty {
                            sectionHeader("Cultural units", systemImage: "person.2.wave.2.fill")
                            ForEach(store.culturalUnits) { unit in
                                Button { store.send(.unitTapped(unit)) } label: {
                                    CulturalUnitRow(unit: unit)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !store.dialectPacks.isEmpty {
                            sectionHeader("Regional forms", systemImage: "map.fill")
                                .padding(.top, 8)
                            ForEach(store.dialectPacks) { pack in
                                Button { store.send(.packTapped(pack)) } label: {
                                    DialectPackRow(pack: pack)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .gjuhaReadableWidth()
            }
        }
        .navigationTitle("Culture & dialects")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.onAppear) }
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.gjuha.accent)
            Text(title)
                .font(.gjuha.headingSmall)
                .foregroundStyle(Color.gjuha.textPrimary)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

private struct CultureEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hourglass")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.gjuha.accent)
            Text("In native-speaker review")
                .font(.gjuha.headingSmall)
                .foregroundStyle(Color.gjuha.textPrimary)
            Text("Cultural and regional lessons are being checked by native speakers before they appear here. The course content you already have is unaffected.")
                .font(.gjuha.caption)
                .foregroundStyle(Color.gjuha.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .gjuhaLiquidGlassCard(cornerRadius: 20, tintOpacity: 0.08)
        .accessibilityElement(children: .combine)
    }
}

private struct CulturalUnitRow: View {
    let unit: CulturalUnit

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.gjuha.accent)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(unit.title)
                    .font(.gjuha.headingSmall)
                    .foregroundStyle(Color.gjuha.textPrimary)
                Text(unit.theme)
                    .font(.gjuha.caption)
                    .foregroundStyle(Color.gjuha.textSecondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.gjuha.textTertiary)
        }
        .padding(16)
        .gjuhaLiquidGlassCard(cornerRadius: 18, tintOpacity: 0.10)
    }
}

private struct DialectPackRow: View {
    let pack: DialectContentPack

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.gjuha.accent)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(pack.title)
                    .font(.gjuha.headingSmall)
                    .foregroundStyle(Color.gjuha.textPrimary)
                Text("\(pack.entries.count) labeled contrasts")
                    .font(.gjuha.caption)
                    .foregroundStyle(Color.gjuha.textSecondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.gjuha.textTertiary)
        }
        .padding(16)
        .gjuhaLiquidGlassCard(cornerRadius: 18, tintOpacity: 0.10)
    }
}

// MARK: - Cultural unit detail

struct CulturalUnitDetailView: View {
    let store: StoreOf<CulturalUnitFeature>

    var body: some View {
        ZStack {
            GjuhaLiquidGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(store.unit.intro)
                        .font(.gjuha.bodyRegular)
                        .foregroundStyle(Color.gjuha.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !store.vocabulary.isEmpty {
                        card(title: "Vocabulary in this unit") {
                            ForEach(store.vocabulary) { line in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(line.albanian)
                                        .font(.gjuha.bodyMedium)
                                        .foregroundStyle(Color.gjuha.textPrimary)
                                    Spacer(minLength: 12)
                                    Text(line.english)
                                        .font(.gjuha.caption)
                                        .foregroundStyle(Color.gjuha.textSecondary)
                                        .multilineTextAlignment(.trailing)
                                }
                                if line.id != store.vocabulary.last?.id {
                                    Divider().overlay(Color.gjuha.border)
                                }
                            }
                        }
                    }

                    if !store.unit.listening.isEmpty {
                        card(title: "Listen") {
                            ForEach(store.unit.listening) { item in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.albanian)
                                        .font(.gjuha.bodyMedium)
                                        .foregroundStyle(Color.gjuha.textPrimary)
                                    Text(item.english)
                                        .font(.gjuha.caption)
                                        .foregroundStyle(Color.gjuha.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                if item.id != store.unit.listening.last?.id {
                                    Divider().overlay(Color.gjuha.border)
                                }
                            }
                            if !store.unit.hasPlayableAudio {
                                Text("Audio is added once a native speaker records it. No machine voice is used for Albanian.")
                                    .font(.gjuha.caption)
                                    .foregroundStyle(Color.gjuha.textTertiary)
                                    .padding(.top, 4)
                            }
                        }
                    }

                    if !store.unit.grammarTopicSeedIds.isEmpty {
                        Text("Reinforces \(store.unit.grammarTopicSeedIds.count) grammar point\(store.unit.grammarTopicSeedIds.count == 1 ? "" : "s") from your course.")
                            .font(.gjuha.caption)
                            .foregroundStyle(Color.gjuha.textSecondary)
                    }

                    if !store.unit.reviewPromptWordIds.isEmpty {
                        Button {
                            store.send(.practiceTapped(store.unit.reviewPromptWordIds))
                        } label: {
                            Text("Practice these words")
                                .font(.gjuha.labelBold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.gjuha.accent, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Starts a spaced repetition session over this unit's words")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .gjuhaReadableWidth()
            }
        }
        .navigationTitle(store.unit.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.onAppear) }
    }

    @ViewBuilder
    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.gjuha.headingSmall)
                .foregroundStyle(Color.gjuha.textPrimary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .gjuhaLiquidGlassCard(cornerRadius: 18, tintOpacity: 0.08)
    }
}

// MARK: - Dialect pack detail

struct DialectPackDetailView: View {
    let store: StoreOf<DialectPackFeature>

    var body: some View {
        ZStack {
            GjuhaLiquidGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(store.pack.summary)
                        .font(.gjuha.bodyRegular)
                        .foregroundStyle(Color.gjuha.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(store.pack.intendedLearner)
                        .font(.gjuha.caption)
                        .foregroundStyle(Color.gjuha.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(store.pack.entries) { entry in
                        DialectEntryCard(entry: entry)
                    }

                    Text("Regional forms are shown so you recognize them. The course teaches Standard Albanian; neither form is wrong, and usage varies by region and family.")
                        .font(.gjuha.caption)
                        .foregroundStyle(Color.gjuha.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .gjuhaReadableWidth()
            }
        }
        .navigationTitle(store.pack.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DialectEntryCard: View {
    let entry: DialectEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.gloss)
                .font(.gjuha.captionBold)
                .foregroundStyle(Color.gjuha.textTertiary)
                .textCase(.uppercase)

            HStack(alignment: .top, spacing: 12) {
                formColumn(label: "Standard", value: entry.standardForm)
                Divider().overlay(Color.gjuha.border)
                formColumn(label: "Regional", value: entry.dialectForm)
            }

            Text(entry.usageNote)
                .font(.gjuha.caption)
                .foregroundStyle(Color.gjuha.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(entry.region)
                .font(.gjuha.caption)
                .foregroundStyle(Color.gjuha.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .gjuhaLiquidGlassCard(cornerRadius: 18, tintOpacity: 0.08)
    }

    private func formColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.gjuha.caption)
                .foregroundStyle(Color.gjuha.textTertiary)
            Text(value)
                .font(.gjuha.bodyMedium)
                .foregroundStyle(Color.gjuha.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
