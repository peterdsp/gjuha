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

// MARK: - Dependency

private enum ContentCatalogKey: DependencyKey {
    static let liveValue: any ContentCatalog = LiveContentCatalog()
    static let testValue: any ContentCatalog = LiveContentCatalog()
}

extension DependencyValues {
    var contentCatalog: any ContentCatalog {
        get { self[ContentCatalogKey.self] }
        set { self[ContentCatalogKey.self] = newValue }
    }
}
