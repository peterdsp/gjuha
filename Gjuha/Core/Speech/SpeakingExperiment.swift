import Foundation
import Dependencies

#if canImport(Speech)
import Speech
#endif

// MARK: - Experiment flags

/// Flags for bounded Phase 4 experiments. Everything is OFF by default. Turning
/// a flag on is a deliberate, reversible step and never uploads data or incurs
/// cost by itself; cloud paths require separate explicit authorization
/// (see `ExperimentBudget`).
struct ExperimentFlags: Equatable, Sendable {
    var speakingEvaluationEnabled: Bool

    init(speakingEvaluationEnabled: Bool = false) {
        self.speakingEvaluationEnabled = speakingEvaluationEnabled
    }

    static let disabledDefault = ExperimentFlags()
}

/// The spending guard for any experiment that could call a paid cloud service.
/// The prototype never spends: the limit is zero and explicit authorization is
/// required before any charge could occur.
struct ExperimentBudget: Equatable, Sendable {
    var monthlyUSDLimit: Double
    var requiresExplicitAuthorization: Bool

    static let noSpendWithoutAuthorization = ExperimentBudget(
        monthlyUSDLimit: 0,
        requiresExplicitAuthorization: true
    )
}

// MARK: - Consent and retention

/// Consent and retention posture for microphone based evaluation. The default
/// denies uploads and retention: audio, if ever captured, stays on device and is
/// discarded after evaluation. Nothing here is acted on while the experiment flag
/// is off.
struct SpeechConsent: Equatable, Sendable {
    var micUsageExplained: Bool
    var uploadsAllowed: Bool
    var retainRecording: Bool

    /// Safe default: the learner has seen why the mic is used, no uploads, no
    /// retention.
    static let privacyPreservingDefault = SpeechConsent(
        micUsageExplained: true,
        uploadsAllowed: false,
        retainRecording: false
    )
}

// MARK: - Locale support probe

/// Whether Apple's speech stack supports a locale at all. This is a read only
/// capability check; it records nothing and needs no permission.
struct SpeechLocaleSupport: Equatable, Sendable {
    var localeIdentifier: String
    var isSupported: Bool
    var note: String
}

// MARK: - Evaluation result

/// A pronunciation assessment, deliberately a separate type from the transcript.
/// It is never derived from speech recognition confidence: recognizing the right
/// words says nothing about how well they were pronounced. Until a real
/// pronunciation assessor exists for Albanian, this stays `.unavailable`.
enum PronunciationAssessment: Equatable, Sendable {
    case unavailable(reason: String)
    /// Only ever produced by a genuine pronunciation assessor, never by an ASR
    /// confidence score.
    case scored(accuracy: Double)
}

struct SpeechEvaluationResult: Equatable, Sendable {
    /// The transcription, when available. Nil when the locale is unsupported or
    /// nothing was captured.
    var transcript: String?
    /// Recognition confidence for the transcription, clearly labeled. This is a
    /// transcription signal, NOT a pronunciation score.
    var transcriptionConfidence: Double?
    var pronunciation: PronunciationAssessment
    /// True when the result came from the mock evaluator (fixtures) rather than a
    /// real speech engine.
    var usedMock: Bool
}

// MARK: - Evaluator protocol

protocol SpeakingEvaluator: Sendable {
    func localeSupport(forIdentifier identifier: String) -> SpeechLocaleSupport
    func evaluate(referenceAlbanian: String, consent: SpeechConsent) async -> SpeechEvaluationResult
}

// MARK: - Apple read-only probe

/// A real, read only probe over Apple's Speech framework. It answers "does Apple
/// support this locale at all", using the same locale list as keyboard dictation.
/// It does not record audio and never runs while the experiment flag is off; its
/// value today is the feasibility evidence it produces.
struct AppleSpeechProbe: SpeakingEvaluator {
    func localeSupport(forIdentifier identifier: String) -> SpeechLocaleSupport {
        #if canImport(Speech)
        let supported = SFSpeechRecognizer.supportedLocales()
        let target = identifier.lowercased()
        let language = String(target.prefix(2))
        let matches = supported.contains { locale in
            let id = locale.identifier.lowercased()
            return id == target || id.hasPrefix(language + "-") || id.hasPrefix(language + "_") || id == language
        }
        return SpeechLocaleSupport(
            localeIdentifier: identifier,
            isSupported: matches,
            note: matches
                ? "Apple speech recognition lists this locale."
                : "Apple speech recognition does not list this locale (it mirrors keyboard dictation locales)."
        )
        #else
        return SpeechLocaleSupport(
            localeIdentifier: identifier,
            isSupported: false,
            note: "The Speech framework is not available in this build."
        )
        #endif
    }

    func evaluate(referenceAlbanian: String, consent: SpeechConsent) async -> SpeechEvaluationResult {
        // The prototype does not run a real capture or upload pipeline. Even with
        // a supported locale, transcription is not pronunciation assessment, so
        // pronunciation stays unavailable here by design.
        SpeechEvaluationResult(
            transcript: nil,
            transcriptionConfidence: nil,
            pronunciation: .unavailable(
                reason: "Live speech capture is not enabled in this build. Pronunciation scoring is not derived from recognition."
            ),
            usedMock: false
        )
    }
}

// MARK: - Mock evaluator (default, fixtures)

/// The default evaluator. Returns fixtures so the experiment can be exercised in
/// tests and previews without a microphone, network, or cost. It models the key
/// invariant explicitly: a transcript and its confidence are produced, but
/// pronunciation is left unavailable rather than faked from confidence.
struct MockSpeakingEvaluator: SpeakingEvaluator {
    var fixedTranscript: String
    var fixedConfidence: Double

    init(fixedTranscript: String = "mirëdita", fixedConfidence: Double = 0.82) {
        self.fixedTranscript = fixedTranscript
        self.fixedConfidence = fixedConfidence
    }

    func localeSupport(forIdentifier identifier: String) -> SpeechLocaleSupport {
        SpeechLocaleSupport(
            localeIdentifier: identifier,
            isSupported: false,
            note: "Mock evaluator: no real locale support is claimed."
        )
    }

    func evaluate(referenceAlbanian: String, consent: SpeechConsent) async -> SpeechEvaluationResult {
        SpeechEvaluationResult(
            transcript: fixedTranscript,
            transcriptionConfidence: fixedConfidence,
            pronunciation: .unavailable(
                reason: "Mock evaluator does not assess pronunciation. Recognition confidence is not a pronunciation score."
            ),
            usedMock: true
        )
    }
}

// MARK: - Dependency

private enum SpeakingEvaluatorKey: DependencyKey {
    /// Disabled by default posture: the app uses the mock unless a real evaluator
    /// is deliberately wired in behind the experiment flag.
    static let liveValue: any SpeakingEvaluator = MockSpeakingEvaluator()
    static let testValue: any SpeakingEvaluator = MockSpeakingEvaluator()
}

extension DependencyValues {
    var speakingEvaluator: any SpeakingEvaluator {
        get { self[SpeakingEvaluatorKey.self] }
        set { self[SpeakingEvaluatorKey.self] = newValue }
    }
}
