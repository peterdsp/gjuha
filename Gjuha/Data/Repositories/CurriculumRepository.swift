import Foundation
import Dependencies

// MARK: - Protocol

protocol CurriculumRepository: Sendable {
    func fetchUnits() async -> [LearningUnit]
    func fetchLessons(for unitId: UUID) async -> [LessonSummary]
    func fetchLesson(_ lessonId: UUID) async -> LessonSummary?
}

// MARK: - Dependency Key

private enum CurriculumRepositoryKey: DependencyKey {
    static let liveValue: any CurriculumRepository = LiveCurriculumRepository()
    static let testValue: any CurriculumRepository = MockCurriculumRepository()
}

extension DependencyValues {
    var curriculumRepository: any CurriculumRepository {
        get { self[CurriculumRepositoryKey.self] }
        set { self[CurriculumRepositoryKey.self] = newValue }
    }
}

// MARK: - Live Implementation

final class LiveCurriculumRepository: CurriculumRepository, @unchecked Sendable {
    private let units: [LearningUnit]
    private let lessonsByUnit: [UUID: [LessonSummary]]
    private let lessonsById: [UUID: LessonSummary]

    init(bundle: Bundle = .main) {
        let loaded = Self.loadSeedContent(bundle: bundle)
        self.units = loaded.units
        self.lessonsByUnit = loaded.lessonsByUnit
        self.lessonsById = loaded.lessonsById
    }

    func fetchUnits() async -> [LearningUnit] {
        units
    }

    func fetchLessons(for unitId: UUID) async -> [LessonSummary] {
        lessonsByUnit[unitId] ?? []
    }

    func fetchLesson(_ lessonId: UUID) async -> LessonSummary? {
        lessonsById[lessonId]
    }

    private static func loadSeedContent(bundle: Bundle) -> (
        units: [LearningUnit],
        lessonsByUnit: [UUID: [LessonSummary]],
        lessonsById: [UUID: LessonSummary]
    ) {
        guard
            let seedUnits: [SeedUnit] = decodeJSON(named: "units", bundle: bundle),
            let seedLessons: [SeedLesson] = decodeJSON(named: "lessons", bundle: bundle)
        else {
            return fallbackSeedContent()
        }

        let orderedLessons = seedLessons.sorted {
            if $0.unit != $1.unit { return $0.unit < $1.unit }
            return $0.order < $1.order
        }

        // Build a lookup for unlock rules
        let unlockRules: [String: [String]] = Dictionary(
            uniqueKeysWithValues: seedLessons.map { ($0.id, $0.unlock.requires_lesson_ids) }
        )

        // Load completed lesson IDs from persistent store
        let completedIds = ProgressStore.shared.completedLessonSeedIds

        var builtUnits: [LearningUnit] = []
        var lessonMapByUnit: [UUID: [LessonSummary]] = [:]
        var lessonMapById: [UUID: LessonSummary] = [:]

        for seedUnit in seedUnits.sorted(by: { $0.unit < $1.unit }) {
            let unitId = stableUUID(for: "unit-\(seedUnit.unit)")
            let unitLessons = orderedLessons
                .filter { $0.unit == seedUnit.unit }
                .enumerated()
                .map { (localIndex, seedLesson) in
                    let isCompleted = completedIds.contains(seedLesson.id)

                    // A lesson is locked if its prerequisites are not all completed
                    let prereqs = unlockRules[seedLesson.id] ?? []
                    let isLocked = !prereqs.isEmpty && !prereqs.allSatisfy { completedIds.contains($0) }

                    let lesson = LessonSummary(
                        id: stableUUID(for: "lesson-\(seedLesson.id)"),
                        seedId: seedLesson.id,
                        title: seedLesson.title,
                        subtitle: subtitle(for: seedLesson),
                        iconName: iconName(for: seedLesson.title),
                        lessonType: lessonType(for: seedLesson.title),
                        isCompleted: isCompleted,
                        bestXP: isCompleted ? ProgressStore.shared.bestXP(for: seedLesson.id) : 0,
                        isLocked: isLocked,
                        orderIndex: localIndex
                    )
                    lessonMapById[lesson.id] = lesson
                    return lesson
                }

            // A unit is locked if ALL its lessons are locked
            let unitIsLocked = !unitLessons.isEmpty && unitLessons.allSatisfy(\.isLocked)

            let description = seedUnit.themes.prefix(3).joined(separator: ", ")
            let unit = LearningUnit(
                id: unitId,
                title: "Unit \(seedUnit.unit) — \(seedUnit.title)",
                description: description.isEmpty ? "Core Albanian practice" : description,
                cefrLevel: parseCEFR(seedUnit.cefr),
                orderIndex: seedUnit.unit - 1,
                lessons: unitLessons,
                isLocked: unitIsLocked
            )

            lessonMapByUnit[unitId] = unitLessons
            builtUnits.append(unit)
        }

        if builtUnits.isEmpty {
            return fallbackSeedContent()
        }

        return (builtUnits, lessonMapByUnit, lessonMapById)
    }

    private static func fallbackSeedContent() -> (
        units: [LearningUnit],
        lessonsByUnit: [UUID: [LessonSummary]],
        lessonsById: [UUID: LessonSummary]
    ) {
        let units = LearningUnit.mockData
        var byUnit: [UUID: [LessonSummary]] = [:]
        var byId: [UUID: LessonSummary] = [:]
        for unit in units {
            byUnit[unit.id] = unit.lessons
            for lesson in unit.lessons {
                byId[lesson.id] = lesson
            }
        }
        return (units, byUnit, byId)
    }

    private static func subtitle(for lesson: SeedLesson) -> String {
        if let first = lesson.objectives.first {
            let stripped = first
                .replacingOccurrences(
                    of: "Understand & use key phrases about: ",
                    with: ""
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if !stripped.isEmpty, stripped.lowercased() != lesson.title.lowercased() {
                return stripped
            }
        }
        return "Complete 5-min micro lessons with typing + listening."
    }

    private static func lessonType(for title: String) -> LessonType {
        let lowered = title.lowercased()
        let grammarHints = [
            "verb", "tense", "grammar", "pronoun", "adjective",
            "case", "conjug", "declension", "negation", "questions"
        ]
        if lowered.contains("review") || lowered.contains("checkpoint") || lowered.contains("final") {
            return .review
        }
        return grammarHints.contains { lowered.contains($0) } ? .grammar : .vocabulary
    }

    private static func iconName(for title: String) -> String {
        let lowered = title.lowercased()
        if lowered.contains("greeting") || lowered.contains("introduc") { return "hand.wave.fill" }
        if lowered.contains("number") || lowered.contains("time") { return "number.circle.fill" }
        if lowered.contains("family") || lowered.contains("people") { return "person.2.fill" }
        if lowered.contains("food") || lowered.contains("coffee") || lowered.contains("shop") { return "fork.knife.circle.fill" }
        if lowered.contains("direction") || lowered.contains("travel") || lowered.contains("transport") { return "map.fill" }
        if lowered.contains("work") || lowered.contains("study") { return "briefcase.fill" }
        if lowered.contains("culture") { return "globe.europe.africa.fill" }
        if lowered.contains("review") || lowered.contains("checkpoint") || lowered.contains("final") { return "checkmark.seal.fill" }
        if lessonType(for: title) == .grammar { return "textformat.abc.dottedunderline" }
        return "book.closed.fill"
    }

    private static func parseCEFR(_ raw: String) -> CEFRLevel {
        CEFRLevel(rawValue: raw.lowercased()) ?? .a1
    }

    private static func decodeJSON<T: Decodable>(named name: String, bundle: Bundle) -> T? {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func stableUUID(for raw: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        for (index, value) in raw.utf8.enumerated() {
            bytes[index % 16] = bytes[index % 16] &+ value
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private struct SeedUnit: Decodable {
        let unit: Int
        let title: String
        let cefr: String
        let themes: [String]
    }

    struct SeedLesson: Decodable {
        let id: String
        let unit: Int
        let order: Int
        let title: String
        let cefr: String
        let objectives: [String]
        let unlock: UnlockRule

        struct UnlockRule: Decodable {
            let requires_lesson_ids: [String]
        }
    }
}

// MARK: - Mock Implementation

final class MockCurriculumRepository: CurriculumRepository, @unchecked Sendable {
    func fetchUnits() async -> [LearningUnit] {
        return LearningUnit.mockData
    }

    func fetchLessons(for unitId: UUID) async -> [LessonSummary] {
        return LearningUnit.mockData
            .first { $0.id == unitId }?
            .lessons ?? []
    }

    func fetchLesson(_ lessonId: UUID) async -> LessonSummary? {
        return LearningUnit.mockData
            .flatMap { $0.lessons }
            .first { $0.id == lessonId }
    }
}

// MARK: - Mock Data

extension LearningUnit {
    static let mockData: [LearningUnit] = [
        LearningUnit(
            id: UUID(),
            title: "Unit 1 — Basics",
            description: "Greetings, introductions, and the verb 'to be'",
            cefrLevel: .a1,
            orderIndex: 0,
            lessons: LessonSummary.unit1Summaries
        ),
        LearningUnit(
            id: UUID(),
            title: "Unit 2 — Everyday Life",
            description: "Family, food, home, and daily routines",
            cefrLevel: .a1,
            orderIndex: 1,
            lessons: [],
            isLocked: true
        ),
    ]
}

extension LessonSummary {
    static let unit1Summaries: [LessonSummary] = [
        LessonSummary(
            seedId: "L001",
            title: "Greetings",
            subtitle: "Say hello in Albanian",
            iconName: "hand.wave.fill",
            lessonType: .vocabulary
        ),
        LessonSummary(
            seedId: "L002",
            title: "To be: jam",
            subtitle: "Conjugate the verb 'jam'",
            iconName: "person.fill",
            lessonType: .grammar,
            isLocked: true,
            orderIndex: 1
        ),
        LessonSummary(
            seedId: "L003",
            title: "Numbers 1-10",
            subtitle: "Count in Albanian",
            iconName: "number.circle.fill",
            lessonType: .vocabulary,
            isLocked: true,
            orderIndex: 2
        ),
    ]
}
