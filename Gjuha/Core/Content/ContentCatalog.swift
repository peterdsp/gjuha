import Foundation
import Dependencies

/// The gate that keeps unreviewed content out of production.
///
/// Every distinctive content item (dialect packs, cultural units) ships as
/// `pendingNativeReview` until a native speaker signs off. The production
/// accessors return only `nativeReviewed` items, so the app can carry the full
/// infrastructure and sample content without ever showing unreviewed language to
/// learners. The `all...` accessors expose everything for review tooling and
/// tests only.
protocol ContentCatalog: Sendable {
    func productionDialectPacks() async -> [DialectContentPack]
    func allDialectPacks() async -> [DialectContentPack]
    func productionCulturalUnits() async -> [CulturalUnit]
    func allCulturalUnits() async -> [CulturalUnit]
}

final class LiveContentCatalog: ContentCatalog, @unchecked Sendable {
    private let dialectPacks: [DialectContentPack]
    private let culturalUnits: [CulturalUnit]

    init(
        dialectPacks: [DialectContentPack] = [.ghegDiasporaSampleV1],
        culturalUnits: [CulturalUnit] = [.hospitalitySampleV1]
    ) {
        self.dialectPacks = dialectPacks
        self.culturalUnits = culturalUnits
    }

    func productionDialectPacks() async -> [DialectContentPack] {
        dialectPacks.filter { $0.reviewStatus == .nativeReviewed }
    }

    func allDialectPacks() async -> [DialectContentPack] {
        dialectPacks
    }

    func productionCulturalUnits() async -> [CulturalUnit] {
        culturalUnits.filter { $0.reviewStatus == .nativeReviewed }
    }

    func allCulturalUnits() async -> [CulturalUnit] {
        culturalUnits
    }
}

#if DEBUG
extension LiveContentCatalog {
    /// A catalog whose sample dialect pack and cultural unit are marked
    /// `nativeReviewed` so the learner-facing flows (navigation, presentation,
    /// exercises, progress) can be exercised end to end.
    ///
    /// This is ISOLATED TEST SCAFFOLDING, never production: it exists only in
    /// DEBUG builds and is only selected when the app is launched with the
    /// explicit `-GjuhaCultureFixtures` argument (see `ContentCatalogKey`). It
    /// asserts nothing about native approval. The real sample content stays
    /// `pendingNativeReview` and is still held out of any normal launch.
    static func cultureFixtureCatalog() -> LiveContentCatalog {
        LiveContentCatalog(
            dialectPacks: [DialectContentPack.ghegDiasporaSampleV1.markedReviewedForFixture],
            culturalUnits: [CulturalUnit.hospitalitySampleV1.markedReviewedForFixture]
        )
    }

    /// True when the app was launched to exercise the culture flows with fixtures.
    static var cultureFixturesRequested: Bool {
        CommandLine.arguments.contains("-GjuhaCultureFixtures")
    }
}

extension DialectContentPack {
    /// A copy flipped to `nativeReviewed` for isolated fixture verification only.
    var markedReviewedForFixture: DialectContentPack {
        var copy = self
        copy.reviewStatus = .nativeReviewed
        return copy
    }
}

extension CulturalUnit {
    /// A copy flipped to `nativeReviewed` for isolated fixture verification only.
    var markedReviewedForFixture: CulturalUnit {
        var copy = self
        copy.reviewStatus = .nativeReviewed
        return copy
    }
}
#endif

// MARK: - Dependency

private enum ContentCatalogKey: DependencyKey {
    static var liveValue: any ContentCatalog {
        #if DEBUG
        if LiveContentCatalog.cultureFixturesRequested {
            return LiveContentCatalog.cultureFixtureCatalog()
        }
        #endif
        return LiveContentCatalog()
    }
    static let testValue: any ContentCatalog = LiveContentCatalog()
}

extension DependencyValues {
    var contentCatalog: any ContentCatalog {
        get { self[ContentCatalogKey.self] }
        set { self[ContentCatalogKey.self] = newValue }
    }
}
