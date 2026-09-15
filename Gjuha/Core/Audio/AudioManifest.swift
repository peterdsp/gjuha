import Foundation

/// Explicit, versioned description of the pronunciation audio the app can play.
///
/// The manifest is the single source of truth for *which* words have audio and
/// *where that audio came from*. It is deliberately separate from the audio
/// files: an entry can exist while its file is still pending generation or
/// native-speaker review, and the loader treats such an entry as "not available"
/// rather than silently playing nothing. See `Resources/Audio/audio_manifest.json`
/// and `Scripts/tools/generate_audio.py`.
struct AudioManifest: Decodable, Sendable, Equatable {
    let version: String
    let generator: String?
    let notes: String?
    let assets: [AudioAsset]

    struct AudioAsset: Decodable, Sendable, Equatable {
        /// Canonical vocabulary identifier (e.g. `w001`) the clip pronounces.
        let wordId: String
        /// The Albanian text that was spoken, for provenance and verification.
        let text: String
        /// File name including extension, resolved inside the bundled audio folder.
        let file: String
        /// How the audio was produced, e.g. `azure-neural`, `native-recording`,
        /// `apple-say-dev`. Recorded so unreviewed machine audio is never mistaken
        /// for approved content.
        let provider: String
        /// Provider voice identifier, when applicable (e.g. `sq-AL-AnilaNeural`).
        let voice: String?
        /// License covering redistribution of the generated clip.
        let license: String?
        /// Native-speaker reviewed and approved for production. Only reviewed
        /// assets back graded listening exercises.
        let reviewed: Bool
        let generatedAt: String?
        let checksum: String?
    }

    static let empty = AudioManifest(version: "0", generator: nil, notes: nil, assets: [])
}
