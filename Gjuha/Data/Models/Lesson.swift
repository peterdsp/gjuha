import Foundation
import SwiftData

@Model
final class Lesson {
    var id: UUID
    var title: String
    var subtitle: String
    var unitId: UUID
    var cefrLevel: CEFRLevel
    var iconName: String
    var orderIndex: Int
    var lessonType: LessonType
    var focusGrammarTopicId: UUID?
    var vocabularyIds: [UUID]
    var isCompleted: Bool
    var completedAt: Date?
    var bestXP: Int

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        unitId: UUID,
        cefrLevel: CEFRLevel,
        iconName: String,
        orderIndex: Int,
        lessonType: LessonType,
        focusGrammarTopicId: UUID? = nil,
        vocabularyIds: [UUID] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.unitId = unitId
        self.cefrLevel = cefrLevel
        self.iconName = iconName
        self.orderIndex = orderIndex
        self.lessonType = lessonType
        self.focusGrammarTopicId = focusGrammarTopicId
        self.vocabularyIds = vocabularyIds
        self.isCompleted = false
        self.completedAt = nil
        self.bestXP = 0
    }
}

enum LessonType: String, Codable {
    case vocabulary
    case grammar
    case listening
    case speaking
    case reading
    case culture
    case review
}

/// Lightweight value type used in TCA State — mirrors Lesson without @Model reference
struct LessonSummary: Identifiable, Equatable, Sendable {
    let id: UUID
    let seedId: String
    let title: String
    let subtitle: String
    let iconName: String
    let lessonType: LessonType
    var isCompleted: Bool
    var bestXP: Int
    var isLocked: Bool
    let orderIndex: Int

    init(from lesson: Lesson) {
        self.id = lesson.id
        self.seedId = ""
        self.title = lesson.title
        self.subtitle = lesson.subtitle
        self.iconName = lesson.iconName
        self.lessonType = lesson.lessonType
        self.isCompleted = lesson.isCompleted
        self.bestXP = lesson.bestXP
        self.isLocked = false
        self.orderIndex = lesson.orderIndex
    }

    init(
        id: UUID = UUID(),
        seedId: String = "",
        title: String,
        subtitle: String,
        iconName: String,
        lessonType: LessonType,
        isCompleted: Bool = false,
        bestXP: Int = 0,
        isLocked: Bool = false,
        orderIndex: Int = 0
    ) {
        self.id = id
        self.seedId = seedId
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.lessonType = lessonType
        self.isCompleted = isCompleted
        self.bestXP = bestXP
        self.isLocked = isLocked
        self.orderIndex = orderIndex
    }
}

struct LearningUnit: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let cefrLevel: CEFRLevel
    let orderIndex: Int
    var lessons: [LessonSummary]
    var isLocked: Bool

    init(
        id: UUID,
        title: String,
        description: String,
        cefrLevel: CEFRLevel,
        orderIndex: Int,
        lessons: [LessonSummary],
        isLocked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.cefrLevel = cefrLevel
        self.orderIndex = orderIndex
        self.lessons = lessons
        self.isLocked = isLocked
    }
}
