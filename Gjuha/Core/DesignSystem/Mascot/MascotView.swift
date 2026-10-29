import SwiftUI
import UIKit
import ImageIO
import CoreGraphics

// MARK: - Frame source

/// The looping mascot animation, decoded by Image I/O.
///
/// This replaced a `WKWebView` per mascot. The previous implementation
/// base64-encoded the 1.2 MB GIF into an HTML string and handed it to a web view
/// to play, which meant:
///
/// - **A web content process per mascot.** `WKWebView` runs out of process, so
///   every mascot on screen started one. Grammar and Words each place two
///   (an inline 34pt one and an 78pt empty state), so a learner browsing
///   vocabulary could have several running to show a looping badge.
/// - **A 1.6 MB string built on each load.** Base64 inflates the asset by about
///   a third, and `updateUIView` rebuilt the document whenever its fingerprint
///   changed.
/// - **WebKit linked for a decoration.** The app has no web content; the whole
///   framework was pulled in to play a GIF.
///
/// `CGAnimateImageDataWithBlock` is the API Apple provides for exactly this. It
/// decodes frames on demand and honours the GIF's own per-frame delays, so memory
/// stays at a frame or two rather than the 25 MB that holding all 37 frames of a
/// 420x420 loop would cost.
enum MascotLoop {
    /// The GIF bytes, or nil when the asset is missing. Missing is survivable:
    /// the view falls back to the still mascot image.
    static var data: Data? {
        NSDataAsset(name: "MascotLoop")?.data
    }

    /// A frame is wrapped so it can cross an `AsyncStream`.
    ///
    /// `CGImage` is a reference type that Image I/O hands back already finished
    /// and never mutates afterwards, so passing it between the animation callback
    /// and the view is safe. The compiler cannot see that, hence the unchecked
    /// conformance rather than a copy of every frame.
    struct Frame: @unchecked Sendable {
        let image: CGImage
    }

    /// Frames of the loop, in order, forever, until the consumer stops iterating.
    ///
    /// Cancelling the consuming task terminates the stream, which sets the
    /// animation's stop flag on the next tick, so a mascot that scrolls off
    /// screen stops decoding rather than animating invisibly.
    static func frames(from data: Data) -> AsyncStream<Frame> {
        AsyncStream { continuation in
            CGAnimateImageDataWithBlock(data as CFData, nil) { _, image, stop in
                // `YieldResult` is not Equatable, so match the terminated case
                // rather than comparing. Terminated means the consuming task was
                // cancelled, which is the signal to stop decoding.
                switch continuation.yield(Frame(image: image)) {
                case .terminated:
                    stop.pointee = true
                    continuation.finish()
                case .enqueued, .dropped:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
}

// MARK: - View

/// The mascot, animated where that is wanted and still where it is not.
struct AnimatedMascotView: View {
    let size: CGFloat
    let usesGlassOrb: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var currentFrame: CGImage?
    @State private var float = false

    init(size: CGFloat, usesGlassOrb: Bool = true) {
        self.size = size
        self.usesGlassOrb = usesGlassOrb
    }

    private var artSize: CGFloat {
        usesGlassOrb ? size - 14 : size
    }

    var body: some View {
        ZStack {
            if usesGlassOrb {
                Circle()
                    .fill(Color.gjuha.accent.opacity(0.2))
                    .frame(width: size + 8, height: size + 8)
                    .blur(radius: 12)

                Circle()
                    .fill(GjuhaSurfaceStyle.restingControlFill(reduceTransparency: reduceTransparency))
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(Color.gjuha.hairline, lineWidth: 0.8)
                    )
            }

            // Reduce Motion gets the still mascot. Gating only the fallback
            // image, as an earlier version did, left the looping animation
            // playing for exactly the people who asked for less motion.
            if let currentFrame, !reduceMotion {
                Image(decorative: currentFrame, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFit()
                    .frame(width: artSize, height: artSize)
                    .clipShape(Circle())
            } else {
                stillMascot
            }
        }
        // Keyed on Reduce Motion so turning the setting on mid-session stops the
        // task rather than leaving it decoding frames nothing displays.
        .task(id: reduceMotion) {
            guard !reduceMotion, let data = MascotLoop.data else { return }
            for await frame in MascotLoop.frames(from: data) {
                currentFrame = frame.image
            }
        }
        .onAppear {
            if reduceMotion { return }
            float = true
        }
        // One element, and a decorative one: the mascot repeats what the text
        // beside it already says, so VoiceOver skips it rather than announcing
        // an image with no information in it.
        .accessibilityHidden(true)
    }

    private var stillMascot: some View {
        Image("MascotIcon")
            .resizable()
            .scaledToFit()
            .frame(width: usesGlassOrb ? size - 16 : size, height: usesGlassOrb ? size - 16 : size)
            .scaleEffect(float ? 1.03 : 0.94)
            .rotationEffect(.degrees(float ? -1.8 : 1.8))
            .offset(y: float ? -2 : 3)
            .animation(
                reduceMotion
                ? .linear(duration: 0.01)
                : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                value: float
            )
    }
}
