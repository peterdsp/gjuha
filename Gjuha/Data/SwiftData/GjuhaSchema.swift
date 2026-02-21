import SwiftData
import Foundation

enum GjuhaSchema {
    static var container: ModelContainer = {
        let schema = Schema([
            Word.self,
            Lesson.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }()
}
