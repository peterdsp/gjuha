import Foundation

/// A short listening line inside a cultural unit. Audio plays only when a
/// reviewed recording exists (`audioAssetId != nil`). There is deliberately no
/// synthetic speech fallback: Apple ships no Albanian text to speech voice, so
/// playing machine Albanian would teach wrong pronunciation.
struct CulturalListeningItem: Equatable, Sendable, Codable, Identifiable {
    var id: String
    var albanian: String
    var english: String
    var audioAssetId: String?

    init(id: String, albanian: String, english: String, audioAssetId: String? = nil) {
        self.id = id
        self.albanian = albanian
        self.english = english
        self.audioAssetId = audioAssetId
    }
}

/// A cultural unit ties a real life situation (family, hospitality, travel,
/// everyday conventions) to the four things a lesson needs: vocabulary, grammar,
/// listening, and review. References point at existing reviewed seed content by
/// stable id, so a unit never inlines new unreviewed language.
struct CulturalUnit: Equatable, Sendable, Codable, Identifiable {
    var id: String
    var title: String
    var theme: String
    var intro: String
    var reviewStatus: ReviewStatus
    /// Seed vocabulary ids (for example "w028") reused by this unit.
    var vocabularyIds: [String]
    /// Grammar seed ids (for example "g001") this unit reinforces.
    var grammarTopicSeedIds: [String]
    var listening: [CulturalListeningItem]
    /// Words recycled into the unit's review step.
    var reviewPromptWordIds: [String]

    /// True only when at least one listening item has reviewed recorded audio.
    /// Currently false for every unit until native audio is contributed.
    var hasPlayableAudio: Bool {
        listening.contains { $0.audioAssetId != nil }
    }

    /// A unit is fully wired when it connects all four learning dimensions. Used
    /// by tests to guarantee cultural units are never a vocabulary only stub.
    var isFullyWired: Bool {
        !vocabularyIds.isEmpty
            && !grammarTopicSeedIds.isEmpty
            && !listening.isEmpty
            && !reviewPromptWordIds.isEmpty
    }
}

// MARK: - Sample unit (held pending native review)

extension CulturalUnit {
    /// Hospitality (mikpritja) is a defining part of Albanian social life: how
    /// guests are welcomed, the ritual of coffee, and the language of offering
    /// and refusing politely. This sample wires that theme to existing vocabulary
    /// and grammar and to a small listening set. It is held pending native review
    /// so cultural framing and the Albanian lines are checked before learners see
    /// it. The intro avoids sweeping generalizations and sticks to concrete,
    /// observable conventions.
    static let hospitalitySampleV1 = CulturalUnit(
        id: "culture.hospitality.v1",
        title: "Mikpritja: welcoming a guest",
        theme: "Hospitality",
        intro: "Being welcomed often starts with coffee and a few set phrases. This unit covers offering, accepting, and politely declining, and the everyday words around a visit. Customs vary between families and regions.",
        reviewStatus: .pendingNativeReview,
        vocabularyIds: ["w006", "w007", "w028", "w046", "w051", "w056", "w068"],
        grammarTopicSeedIds: ["g001", "g002"],
        listening: [
            CulturalListeningItem(
                id: "culture.hospitality.listen.welcome",
                albanian: "Mirë se vjen! Urdhëro, hyr brenda.",
                english: "Welcome! Please, come inside."
            ),
            CulturalListeningItem(
                id: "culture.hospitality.listen.coffee",
                albanian: "A do një kafe?",
                english: "Would you like a coffee?"
            ),
            CulturalListeningItem(
                id: "culture.hospitality.listen.thanks",
                albanian: "Faleminderit, jo tani.",
                english: "Thank you, not right now."
            ),
        ],
        reviewPromptWordIds: ["w006", "w028", "w051"]
    )
}
