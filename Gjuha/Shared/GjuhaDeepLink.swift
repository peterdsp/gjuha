import Foundation

/// The deep links Gjuha accepts from outside the app.
///
/// Shared between the app and the widget extension so the two can never disagree
/// about the URL shape. Widget tap targets build these; `AppView` parses them.
///
/// Accessory (Lock Screen) widget families cannot host a `Button(intent:)`, so a
/// URL is the one tap mechanism that works in every widget family. The App
/// Intents entry points funnel into the same router, so Siri, Shortcuts, and a
/// widget tap all take identical code paths into the app's state.
///
/// Treat these paths as a published contract, like an intent identifier: a
/// widget installed on a Home Screen keeps sending the URL it was built with, so
/// adding a case is safe and renaming one breaks already-placed widgets.
enum GjuhaDeepLink: Equatable, Sendable {
    /// Start a spaced repetition session over whatever is due now.
    case startReview
    /// Resume the saved lesson, or open the next unlocked incomplete lesson.
    case continueLearning
    /// Open the Profile tab, where the honest progress breakdown lives.
    case progress

    static let scheme = "gjuha"

    var url: URL {
        // Force unwrap is safe: every case maps to a fixed, valid literal URL,
        // and a typo here would fail in the first widget render in development.
        URL(string: "\(Self.scheme)://\(host)")!
    }

    private var host: String {
        switch self {
        case .startReview: "review"
        case .continueLearning: "continue"
        case .progress: "progress"
        }
    }

    /// Parses an incoming URL, returning nil for anything unrecognised so an
    /// unknown or malformed link is ignored rather than mishandled.
    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }
        // Tolerate both gjuha://review and gjuha:///review shapes.
        let candidate = (url.host() ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
            .lowercased()
        switch candidate {
        case "review": self = .startReview
        case "continue": self = .continueLearning
        case "progress": self = .progress
        default: return nil
        }
    }
}
