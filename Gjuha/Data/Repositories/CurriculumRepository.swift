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
    func fetchUnits() async -> [LearningUnit] {
        // TODO: Load from SwiftData seeded from JSON
        return []
    }

    func fetchLessons(for unitId: UUID) async -> [LessonSummary] {
        return []
    }

    func fetchLesson(_ lessonId: UUID) async -> LessonSummary? {
        return nil
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
            lessons: []
        ),
    ]
}

extension LessonSummary {
    static let unit1Summaries: [LessonSummary] = [
        LessonSummary(
            title: "Greetings",
            subtitle: "Say hello in Albanian",
            iconName: "hand.wave.fill",
            lessonType: .vocabulary
        ),
        LessonSummary(
            title: "To be: jam",
            subtitle: "Conjugate the verb 'jam'",
            iconName: "person.fill",
            lessonType: .grammar
        ),
        LessonSummary(
            title: "Numbers 1–10",
            subtitle: "Count in Albanian",
            iconName: "number.circle.fill",
            lessonType: .vocabulary
        ),
    ]
}
