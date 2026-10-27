import SwiftData
import Foundation

enum GjuhaSchema {
    /// The SwiftData container attached to the scene.
    ///
    /// Two things about this are worth knowing before relying on it.
    ///
    /// **The store location is pinned deliberately.** CoreData, which backs
    /// SwiftData, resolves its default store directory to the *App Group*
    /// container when the app is entitled to exactly one app group. Adding the
    /// App Group for the widget therefore moved this store without a line of
    /// code changing, which is invisible until something depends on it. Today
    /// that is harmless (see below), but it would silently relocate real data
    /// the moment any is written. The URL is explicit so that cannot happen: the
    /// store stays in the app's own container, and the App Group holds only the
    /// derived widget projection it was added for.
    ///
    /// **Nothing currently reads or writes this container.** `Word` and `Lesson`
    /// are declared `@Model`, but every piece of data the app actually uses comes
    /// from the JSON seed through the repositories, and everything the learner
    /// produces lives in `ProgressStore`, `ReviewStore`, and
    /// `LessonSessionStore`, all UserDefaults backed. So this is scaffolding for
    /// later, not a live store. The `fatalError` below is consequently a
    /// liability rather than a safeguard: it can stop the app launching over a
    /// store that nothing needs. Before anything starts writing here, decide
    /// whether a container failure should be survivable.
    nonisolated(unsafe) static var container: ModelContainer = {
        let schema = Schema([
            Word.self,
            Lesson.self,
        ])

        let config = ModelConfiguration(schema: schema, url: storeURL())

        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }()

    /// The store file, inside the app's own Application Support directory.
    ///
    /// The directory is created if missing: on a clean install it does not exist
    /// yet, and CoreData logs a wall of stat and sandbox errors while it works
    /// that out, which makes a healthy launch look broken in the console.
    private static func storeURL() -> URL {
        let fileManager = FileManager.default
        let support = URL.applicationSupportDirectory

        if !fileManager.fileExists(atPath: support.path(percentEncoded: false)) {
            try? fileManager.createDirectory(at: support, withIntermediateDirectories: true)
        }

        return support.appending(path: "Gjuha.store")
    }
}
