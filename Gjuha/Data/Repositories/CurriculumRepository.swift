import Foundation
import Dependencies

// MARK: - Protocol

protocol CurriculumRepository {
    func fetchUnits() async -> [LearningUnit]
    func fetchLessons(for unitId: UUID) async -> [Lesson]
    func fetchLesson(_ lessonId: UUID) async -> Lesson?
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

final class LiveCurriculumRepository: CurriculumRepository {
    func fetchUnits() async -> [LearningUnit] {
        // TODO: Load from SwiftData seeded from JSON
        return []
    }

    func fetchLessons(for unitId: UUID) async -> [Lesson] {
        return []
    }

    func fetchLesson(_ lessonId: UUID) async -> Lesson? {
        return nil
    }
}

// MARK: - Mock Implementation

final class MockCurriculumRepository: CurriculumRepository {
    func fetchUnits() async -> [LearningUnit] {
        return LearningUnit.mockData
    }

    func fetchLessons(for unitId: UUID) async -> [Lesson] {
        return LearningUnit.mockData
            .first { $0.id == unitId }?
            .lessons ?? []
    }

    func fetchLesson(_ lessonId: UUID) async -> Lesson? {
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
            lessons: Lesson.unit1Lessons
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

extension Lesson {
    static let unit1Lessons: [Lesson] = [
        Lesson(
            title: "Greetings",
            subtitle: "Say hello in Albanian",
            unitId: UUID(),
            cefrLevel: .a1,
            iconName: "hand.wave.fill",
            orderIndex: 0,
            lessonType: .vocabulary
        ),
        Lesson(
            title: "To be: jam",
            subtitle: "Conjugate the verb 'jam'",
            unitId: UUID(),
            cefrLevel: .a1,
            iconName: "person.fill",
            orderIndex: 1,
            lessonType: .grammar
        ),
        Lesson(
            title: "Numbers 1–10",
            subtitle: "Count in Albanian",
            unitId: UUID(),
            cefrLevel: .a1,
            iconName: "number.circle.fill",
            orderIndex: 2,
            lessonType: .vocabulary
        ),
    ]
}
