import WidgetKit
import Foundation

/// One rendered moment of the widget.
struct GjuhaEntry: TimelineEntry {
    let date: Date
    let snapshot: GjuhaWidgetSnapshot

    /// Whether this entry's counts can still be trusted. The rule itself lives on
    /// `GjuhaWidgetSnapshot` so it is unit testable from the app's test target.
    var isStale: Bool { snapshot.isStale(on: date) }

    /// True before the app has ever written a projection, or when the App Group is
    /// not available to this build.
    var isPlaceholder: Bool { !snapshot.isRealData }
}

/// Serves the widget from the projection the app writes.
///
/// There is no configuration, so this is a plain `TimelineProvider`. The app calls
/// `WidgetCenter.reloadAllTimelines()` whenever learner state changes, which is
/// what actually keeps the widget current. The scheduled entry below exists only
/// to flip the widget into its stale state at midnight if the app has not been
/// opened since.
struct GjuhaTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> GjuhaEntry {
        GjuhaEntry(date: Date(), snapshot: .gallerySample)
    }

    func getSnapshot(in context: Context, completion: @escaping (GjuhaEntry) -> Void) {
        // In the gallery, show the representative sample so the widget does not
        // look broken; on a real Home Screen, show the learner's actual state.
        let snapshot = context.isPreview
            ? GjuhaWidgetSnapshot.gallerySample
            : (WidgetSnapshotStore.shared.load() ?? .placeholder)
        completion(GjuhaEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GjuhaEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSnapshotStore.shared.load() ?? .placeholder
        let calendar = Calendar.current
        let nextMidnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(60 * 60 * 24)

        let entries = [
            GjuhaEntry(date: now, snapshot: snapshot),
            GjuhaEntry(date: nextMidnight, snapshot: snapshot)
        ]

        completion(Timeline(entries: entries, policy: .after(nextMidnight)))
    }
}
