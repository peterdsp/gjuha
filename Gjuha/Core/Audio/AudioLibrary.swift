import Foundation

/// Loads the audio manifest and resolves manifest entries to playable files,
/// but only when the file actually exists. This is what keeps a missing or
/// pending asset from being wired into a lesson: a listening exercise is only
/// offered when `url(forWordId:requireReviewed:)` returns a real, reviewed file.
///
/// File resolution is injected so the loader is fully testable without a bundle.
final class AudioLibrary: @unchecked Sendable {
    static let shared = AudioLibrary()

    let manifest: AudioManifest
    private let byWordId: [String: AudioManifest.AudioAsset]
    private let resolveFile: @Sendable (String) -> URL?

    /// - Parameter resolveFile: maps a manifest `file` name to a URL when the
    ///   file is present, or `nil` when it is missing.
    init(manifest: AudioManifest, resolveFile: @escaping @Sendable (String) -> URL?) {
        self.manifest = manifest
        self.resolveFile = resolveFile
        self.byWordId = Dictionary(
            manifest.assets.map { ($0.wordId, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    convenience init(bundle: Bundle = .main) {
        let manifest = Self.loadManifest(bundle: bundle)
        self.init(manifest: manifest, resolveFile: { file in
            Self.bundledURL(for: file, bundle: bundle)
        })
    }

    /// The reviewed, present audio file for a word, or `nil`. Passing
    /// `requireReviewed: false` also returns unreviewed development audio (used
    /// by the vocabulary browser's optional playback, never by graded lessons).
    func url(forWordId wordId: String, requireReviewed: Bool) -> URL? {
        guard let asset = byWordId[wordId] else { return nil }
        if requireReviewed && !asset.reviewed { return nil }
        return resolveFile(asset.file)
    }

    func asset(forWordId wordId: String) -> AudioManifest.AudioAsset? {
        byWordId[wordId]
    }

    /// A URL for a manifest file name (e.g. `w001.m4a`) when present in the bundle.
    func url(forFile file: String) -> URL? {
        resolveFile(file)
    }

    /// Whether a graded listening exercise can be built for this word.
    func hasReviewedAudio(forWordId wordId: String) -> Bool {
        url(forWordId: wordId, requireReviewed: true) != nil
    }

    /// Manifest entries whose file is not present in the bundle. An empty result
    /// means every claimed asset ships. Surfaced by a test and a debug assertion
    /// so broken audio wiring fails loudly instead of playing silence.
    func missingAssets() -> [AudioManifest.AudioAsset] {
        manifest.assets.filter { resolveFile($0.file) == nil }
    }

    /// Count of assets approved for production (reviewed and present).
    var reviewedAvailableCount: Int {
        manifest.assets.filter { $0.reviewed && resolveFile($0.file) != nil }.count
    }

    // MARK: - Loading

    private static func loadManifest(bundle: Bundle) -> AudioManifest {
        guard let url = bundle.url(forResource: "audio_manifest", withExtension: "json")
                ?? bundle.url(forResource: "Audio/audio_manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(AudioManifest.self, from: data)
        else {
            return .empty
        }
        return manifest
    }

    private static func bundledURL(for file: String, bundle: Bundle) -> URL? {
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        // Audio ships in an `Audio/` folder reference; fall back to a flat layout.
        return bundle.url(forResource: name, withExtension: ext, subdirectory: "Audio")
            ?? bundle.url(forResource: name, withExtension: ext)
    }
}
