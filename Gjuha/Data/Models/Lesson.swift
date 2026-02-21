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

struct LearningUnit: Identifiable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let cefrLevel: CEFRLevel
    let orderIndex: Int
    var lessons: [Lesson]
}

extension Lesson: Equatable {
    static func == (lhs: Lesson, rhs: Lesson) -> Bool {
        lhs.id == rhs.id
    }
}
