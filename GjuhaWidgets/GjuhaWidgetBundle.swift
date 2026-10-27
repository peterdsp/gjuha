import WidgetKit
import SwiftUI

/// The widget extension's entry point.
///
/// One widget, five families. A second widget would compete with this one in the
/// gallery for no extra information, since everything a learner needs at a glance
/// already fits here.
@main
struct GjuhaWidgetBundle: WidgetBundle {
    var body: some Widget {
        GjuhaProgressWidget()
    }
}
