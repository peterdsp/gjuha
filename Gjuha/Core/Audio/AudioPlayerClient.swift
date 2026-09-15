import Foundation
import Dependencies
@preconcurrency import AVFoundation

// MARK: - Protocol

/// Offline audio playback for pronunciation.
///
/// Two sources, in priority order:
/// 1. A bundled clip (a reviewed native recording or an approved generated file),
///    played from its file URL.
/// 2. On-device speech synthesis, but *only* when an Albanian voice is installed.
///    If no Albanian voice exists, `speakAlbanian` does nothing and returns
///    `false`, so the app never reads Albanian text with a wrong-language voice.
protocol AudioPlayerProtocol: Sendable {
    /// Plays a bundled audio file. No-op when `url` is nil or unreadable.
    func play(url: URL?) async
    /// Speaks Albanian text with an on-device Albanian voice when available.
    /// Returns `false` (and plays nothing) when no Albanian voice is installed.
    @discardableResult func speakAlbanian(_ text: String) async -> Bool
    /// Whether an on-device Albanian voice is installed on this device.
    var albanianVoiceAvailable: Bool { get }
    func stop() async
}

extension AudioPlayerProtocol {
    /// Convenience: play the bundled clip if present, otherwise fall back to an
    /// Albanian system voice. Returns whether anything was (or will be) played.
    @discardableResult
    func playOrSpeak(url: URL?, albanianText: String) async -> Bool {
        if url != nil {
            await play(url: url)
            return true
        }
        return await speakAlbanian(albanianText)
    }
}

// MARK: - Dependency

private enum AudioPlayerKey: DependencyKey {
    static let liveValue: any AudioPlayerProtocol = LiveAudioPlayer()
    static let testValue: any AudioPlayerProtocol = NoopAudioPlayer()
    static let previewValue: any AudioPlayerProtocol = NoopAudioPlayer()
}

extension DependencyValues {
    var audioPlayer: any AudioPlayerProtocol {
        get { self[AudioPlayerKey.self] }
        set { self[AudioPlayerKey.self] = newValue }
    }
}

// MARK: - Live Implementation

final class LiveAudioPlayer: AudioPlayerProtocol, @unchecked Sendable {
    var albanianVoiceAvailable: Bool {
        LiveAudioPlayer.albanianVoice() != nil
    }

    func play(url: URL?) async {
        guard let url else { return }
        await MainActor.run { PlaybackEngine.shared.play(url: url) }
    }

    @discardableResult
    func speakAlbanian(_ text: String) async -> Bool {
        guard let voice = LiveAudioPlayer.albanianVoice() else { return false }
        await MainActor.run { PlaybackEngine.shared.speak(text, voice: voice) }
        return true
    }

    func stop() async {
        await MainActor.run { PlaybackEngine.shared.stop() }
    }

    /// The best installed Albanian voice, or nil. Matches `sq` in the BCP-47
    /// language tag so `sq-AL`, `sq`, etc. all qualify.
    static func albanianVoice() -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.speechVoices().first { voice in
            let code = voice.language.lowercased()
            return code == "sq" || code.hasPrefix("sq-") || code.hasPrefix("sq_")
        }
    }
}

/// Serialises AVFoundation objects (which are not Sendable) onto the main actor.
@MainActor
private final class PlaybackEngine {
    static let shared = PlaybackEngine()

    private var player: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()

    func play(url: URL) {
        stop()
        activateSession()
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        self.player = player
        player.prepareToPlay()
        player.play()
    }

    func speak(_ text: String, voice: AVSpeechSynthesisVoice) {
        stop()
        activateSession()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synthesizer.speak(utterance)
    }

    func stop() {
        player?.stop()
        player = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func activateSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true, options: [])
        #endif
    }
}

// MARK: - No-op Implementation (tests & previews)

final class NoopAudioPlayer: AudioPlayerProtocol, @unchecked Sendable {
    var albanianVoiceAvailable: Bool { false }
    func play(url: URL?) async {}
    @discardableResult func speakAlbanian(_ text: String) async -> Bool { false }
    func stop() async {}
}
