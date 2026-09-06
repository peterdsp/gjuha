import Foundation

// MARK: - Shared content vocabulary

/// The regional variety a form belongs to. The course teaches Standard Albanian
/// (the Tosk based literary norm); dialect packs add clearly labeled regional
/// forms alongside it. A dialect form is never treated as wrong.
enum ContentVariety: String, Equatable, Sendable, Codable {
    case standard
    case gheg
}

enum ContentRegister: String, Equatable, Sendable, Codable {
    case informal
    case neutral
    case formal
}

/// Whether content has been signed off by a native reviewer. Only
/// `nativeReviewed` content is ever exposed to learners in production (see
/// `ContentCatalog`). Everything ships as `pendingNativeReview` until a native
/// speaker reviews it.
enum ReviewStatus: String, Equatable, Sendable, Codable {
    case pendingNativeReview
    case nativeReviewed
}

// MARK: - Dialect content

/// One labeled contrast between the Standard Albanian form the course teaches
/// and a regional (for example Gheg) form a diaspora learner may hear at home.
/// Both forms are valid in their own context. `usageNote` carries the register
/// and regional caveats so no form is presented as universal or as "correct
/// versus wrong".
struct DialectEntry: Equatable, Sendable, Codable, Identifiable {
    var id: String
    var gloss: String
    var standardForm: String
    var dialectForm: String
    var variety: ContentVariety
    var register: ContentRegister
    var usageNote: String
    var region: String
    /// Recorded native audio, when it exists and has been reviewed. Nil until a
    /// consenting native contributor provides it, so nothing plays synthetic
    /// Albanian (Apple has no Albanian voice) or unreviewed audio.
    var audioAssetId: String?

    init(
        id: String,
        gloss: String,
        standardForm: String,
        dialectForm: String,
        variety: ContentVariety,
        register: ContentRegister,
        usageNote: String,
        region: String,
        audioAssetId: String? = nil
    ) {
        self.id = id
        self.gloss = gloss
        self.standardForm = standardForm
        self.dialectForm = dialectForm
        self.variety = variety
        self.register = register
        self.usageNote = usageNote
        self.region = region
        self.audioAssetId = audioAssetId
    }
}

struct DialectContentPack: Equatable, Sendable, Codable, Identifiable {
    var id: String
    var title: String
    var summary: String
    /// The specific learner this pack is designed for, defined up front.
    var intendedLearner: String
    var primaryVariety: ContentVariety
    var reviewStatus: ReviewStatus
    var entries: [DialectEntry]
}

// MARK: - Sample pack (held pending native review)

extension DialectContentPack {
    /// A small, explicitly labeled sample pack for heritage and diaspora learners
    /// who grew up hearing Gheg at home while studying Standard Albanian here.
    ///
    /// Held OUT of the production catalog: `reviewStatus` is `pendingNativeReview`,
    /// so `ContentCatalog.productionDialectPacks()` excludes it until a native
    /// reviewer signs off. Gheg is not a single uniform variety; forms differ by
    /// region and family, which every `usageNote` states explicitly. The entries
    /// below use widely documented, low controversy contrasts as a starting point
    /// for that review, not as a finished authoritative reference.
    static let ghegDiasporaSampleV1 = DialectContentPack(
        id: "pack.gheg.diaspora.v1",
        title: "Home Albanian: Gheg you may hear",
        summary: "Bridges the Standard Albanian taught in the course with common northern Gheg forms that diaspora learners often hear from family.",
        intendedLearner: "Heritage and diaspora learners with family from Kosovo or northern Albania who hear Gheg at home and are learning Standard Albanian in the app.",
        primaryVariety: .gheg,
        reviewStatus: .pendingNativeReview,
        entries: [
            DialectEntry(
                id: "gheg.family.mother",
                gloss: "mother",
                standardForm: "nënë",
                dialectForm: "nanë",
                variety: .gheg,
                register: .neutral,
                usageNote: "Both mean mother. You will hear nanë across much of the north; nënë is the standard written form. Exact vowel varies by area.",
                region: "Kosovo and northern Albania (varies locally)"
            ),
            DialectEntry(
                id: "gheg.greeting.howareyou",
                gloss: "how are you?",
                standardForm: "si je?",
                dialectForm: "qysh je?",
                variety: .gheg,
                register: .informal,
                usageNote: "Everyday informal greeting. qysh (how) is common in the north; si is standard. Both are understood everywhere.",
                region: "Kosovo and northern Albania (varies locally)"
            ),
            DialectEntry(
                id: "gheg.verb.towork.infinitive",
                gloss: "to work (infinitive)",
                standardForm: "të punoj",
                dialectForm: "me punue",
                variety: .gheg,
                register: .neutral,
                usageNote: "Gheg keeps a me plus participle infinitive (me punue) where the standard uses a të plus subjunctive form. This is a well known structural difference, not an error.",
                region: "Northern Albania and Kosovo"
            ),
            DialectEntry(
                id: "gheg.future.iwillgo",
                gloss: "I will go",
                standardForm: "do të shkoj",
                dialectForm: "kam me shku",
                variety: .gheg,
                register: .neutral,
                usageNote: "Future tense. Many Gheg speakers use kam me plus participle; the standard uses do të plus subjunctive. Usage varies by speaker.",
                region: "Northern Albania and Kosovo"
            ),
            DialectEntry(
                id: "gheg.question.where",
                gloss: "where",
                standardForm: "ku",
                dialectForm: "kah",
                variety: .gheg,
                register: .informal,
                usageNote: "kah can mean where or which way in the north; ku is standard. Regional and context dependent.",
                region: "Kosovo and northern Albania (varies locally)"
            ),
        ]
    )
}
