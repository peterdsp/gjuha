import Foundation
import Dependencies

// MARK: - Protocol

protocol ExerciseEngineProtocol: Sendable {
    func generateExercises(for lesson: LessonSummary) async -> [Exercise]
    func checkAnswer(_ answer: String, for exercise: Exercise) -> Bool
}

// MARK: - Dependency Key

private enum ExerciseEngineKey: DependencyKey {
    static let liveValue: any ExerciseEngineProtocol = ExerciseEngine()
    static let testValue: any ExerciseEngineProtocol = MockExerciseEngine()
}

extension DependencyValues {
    var exerciseEngine: any ExerciseEngineProtocol {
        get { self[ExerciseEngineKey.self] }
        set { self[ExerciseEngineKey.self] = newValue }
    }
}

// MARK: - Lesson → Vocabulary Mapping

/// Maps lesson seed IDs to vocabulary word IDs for exercise generation
enum LessonVocabularyMap {
    /// Returns word IDs from the seed vocabulary that match a given lesson topic
    static func wordIds(for lessonSeedId: String, lessonTitle: String) -> [String] {
        if let explicit = explicitMapping[lessonSeedId], !explicit.isEmpty {
            return explicit
        }
        return inferWordIds(from: lessonTitle)
    }

    // MARK: - Explicit mapping for all 120 lessons
    private static let explicitMapping: [String: [String]] = [
        // Unit 1 — A1 Basics
        "L001": ["w001", "w002", "w003", "w004", "w005", "w006", "w007", "w008", "w009"],  // Greetings
        "L002": ["w010", "w011", "w012", "w013", "w014", "w015", "w016", "w017", "w018"],  // Pronouns & to be
        "L003": ["w031", "w032", "w033", "w034", "w035", "w036", "w037", "w038", "w039", "w040", "w041", "w042", "w043"],  // Numbers & time
        "L004": ["w028", "w046", "w047", "w048", "w049", "w050", "w020", "w025"],  // Coffee & ordering
        "L005": ["w051", "w052", "w053", "w054", "w055", "w056", "w057", "w058", "w059", "w060"],  // Family & people
        "L006": ["w061", "w062", "w063", "w064", "w065", "w066", "w067", "w068", "w069", "w070"],  // Food & shopping
        "L007": ["w071", "w072", "w073", "w074", "w075", "w076", "w077", "w078", "w079", "w080"],  // Directions
        "L008": ["w081", "w082", "w083", "w084", "w085", "w086", "w087", "w088", "w089", "w090"],  // Home & daily routine
        "L009": ["w091", "w092", "w093", "w094", "w095", "w096", "w097", "w098", "w099", "w100", "w101"],  // Weather & seasons
        "L010": ["w102", "w103", "w104", "w105", "w106", "w107", "w108", "w109"],  // Simple past intro

        // Unit 2 — A1 Expanding
        "L011": ["w110", "w111", "w112", "w113", "w114", "w115", "w116", "w117", "w118", "w119"],  // Work & study
        "L012": ["w120", "w121", "w122", "w123", "w124", "w125", "w126", "w127", "w128"],  // Transport
        "L013": ["w129", "w130", "w131", "w132", "w133", "w134", "w135", "w306"],  // Health basics
        "L014": ["w136", "w137", "w138", "w139", "w140", "w141", "w142", "w143"],  // At the market
        "L015": ["w144", "w145", "w146", "w147", "w148", "w149", "w150", "w151", "w344"],  // Hobbies
        "L016": ["w152", "w153", "w154", "w155", "w156", "w157", "w158", "w104"],  // Plans (future)
        "L017": ["w159", "w160", "w161", "w162", "w163", "w164", "w165", "w295", "w325"],  // Questions & negation
        "L018": ["w166", "w167", "w168", "w169", "w170", "w171", "w172", "w173", "w174"],  // Places in town
        "L019": ["w175", "w176", "w177", "w178", "w179", "w338", "w339"],  // Phone & messages
        "L020": ["w110", "w120", "w129", "w136", "w144", "w159", "w166", "w175"],  // Review

        // Unit 3 — A1 Descriptions & Past
        "L021": ["w180", "w181", "w182", "w183", "w184", "w185", "w186", "w187", "w188"],  // Describe people
        "L022": ["w189", "w190", "w191", "w192", "w193", "w194", "w195", "w196", "w197", "w198"],  // Adjectives
        "L023": ["w199", "w200", "w201", "w202", "w203", "w204", "w205", "w029"],  // Possession
        "L024": ["w105", "w206", "w207", "w208", "w209", "w210", "w211", "w102"],  // Simple stories (past)
        "L025": ["w212", "w213", "w214", "w006", "w007", "w284", "w285"],  // Politeness
        "L026": ["w215", "w216", "w217", "w218", "w219", "w220", "w221", "w050", "w171"],  // Eating out
        "L027": ["w222", "w223", "w224", "w225", "w300", "w164", "w160", "w303"],  // Small talk
        "L028": ["w226", "w227", "w228", "w229", "w230", "w157", "w286"],  // Appointments
        "L029": ["w231", "w232", "w233", "w234", "w235", "w236", "w237", "w238"],  // Travel basics
        "L030": ["w180", "w189", "w199", "w206", "w212", "w215", "w222", "w231"],  // Review

        // Unit 4 — A1 Daily Life & Grammar
        "L031": ["w081", "w239", "w240", "w241", "w242", "w342", "w343", "w087"],  // Daily habits
        "L032": ["w243", "w244", "w245", "w246", "w247", "w248", "w249", "w250", "w251"],  // Common verbs
        "L033": ["w252", "w253", "w254", "w255", "w256", "w257", "w258"],  // Prepositions
        "L034": ["w259", "w260", "w261", "w262", "w189", "w190", "w095", "w096"],  // Comparisons
        "L035": ["w263", "w264", "w265", "w266", "w267", "w137", "w138", "w139"],  // Shopping dialogues
        "L036": ["w268", "w269", "w270", "w271", "w272", "w273", "w029", "w088"],  // At home
        "L037": ["w274", "w275", "w276", "w277", "w278", "w279", "w111", "w157"],  // At work
        "L038": ["w280", "w281", "w282", "w283", "w284", "w285", "w214"],  // Requests
        "L039": ["w286", "w287", "w288", "w289", "w290", "w291", "w103", "w104"],  // Listening sprint (time words)
        "L040": ["w001", "w018", "w031", "w051", "w071", "w091", "w110", "w136", "w180", "w243"],  // A1 final review

        // Unit 5 — A2 Past & Connectors
        "L041": ["w313", "w314", "w315", "w316", "w317", "w105", "w206", "w211"],  // Past imperfect
        "L042": ["w296", "w297", "w298", "w299", "w318", "w319", "w320", "w321"],  // Connectors
        "L043": ["w322", "w323", "w324", "w159", "w160", "w161", "w162", "w163", "w165"],  // More questions
        "L044": ["w010", "w011", "w012", "w013", "w014", "w015", "w334", "w335"],  // Clitics intro
        "L045": ["w252", "w253", "w254", "w255", "w256", "w258", "w324"],  // Cases intro
        "L046": ["w152", "w153", "w154", "w155", "w156", "w280", "w281"],  // Making suggestions
        "L047": ["w170", "w171", "w147", "w148", "w149", "w150", "w303"],  // Going out
        "L048": ["w155", "w191", "w192", "w259", "w260", "w297", "w299"],  // Opinions
        "L049": ["w339", "w340", "w166", "w301", "w302", "w155", "w245"],  // News snippets
        "L050": ["w313", "w296", "w322", "w010", "w252", "w152", "w170", "w155"],  // Review

        // Unit 6 — A2 Practical Situations
        "L051": ["w175", "w176", "w177", "w178", "w229", "w286", "w227"],  // Phone calls
        "L052": ["w157", "w226", "w227", "w228", "w230", "w285", "w303"],  // Invitations
        "L053": ["w231", "w232", "w233", "w234", "w235", "w236", "w126"],  // Travel situations
        "L054": ["w129", "w130", "w131", "w132", "w133", "w134", "w135", "w306"],  // Health & pharmacy
        "L055": ["w173", "w140", "w276", "w137", "w139", "w282", "w283"],  // At the bank
        "L056": ["w268", "w029", "w088", "w089", "w269", "w270", "w273"],  // Renting/home
        "L057": ["w274", "w275", "w277", "w278", "w279", "w157", "w276"],  // Work meetings
        "L058": ["w263", "w264", "w265", "w266", "w267", "w141", "w283"],  // Shopping returns
        "L059": ["w102", "w206", "w207", "w208", "w211", "w301", "w303"],  // Storytelling
        "L060": ["w175", "w157", "w231", "w129", "w173", "w268", "w274", "w263"],  // Review

        // Unit 7 — A2 Grammar Deep Dive
        "L061": ["w029", "w030", "w088", "w076", "w166", "w110", "w117"],  // Definite/indefinite
        "L062": ["w252", "w253", "w254", "w255", "w256", "w257", "w258", "w323", "w324"],  // Prepositions + cases
        "L063": ["w010", "w011", "w012", "w013", "w014", "w199", "w200", "w334"],  // Pronouns & clitics
        "L064": ["w152", "w153", "w154", "w104", "w158", "w155", "w156"],  // Future plans
        "L065": ["w280", "w281", "w313", "w314", "w297", "w299", "w155"],  // Conditionals
        "L066": ["w259", "w260", "w261", "w189", "w190", "w191", "w192"],  // Comparatives
        "L067": ["w280", "w281", "w282", "w155", "w214", "w285", "w297"],  // Giving advice
        "L068": ["w212", "w213", "w283", "w297", "w319", "w192", "w214"],  // Complaints politely
        "L069": ["w247", "w293", "w294", "w245", "w160", "w164", "w165"],  // Listening sprint
        "L070": ["w029", "w252", "w010", "w152", "w280", "w259", "w212", "w247"],  // Review

        // Unit 8 — A2 Culture & Skills
        "L071": ["w115", "w293", "w155", "w296", "w297", "w299", "w301"],  // Longer texts
        "L072": ["w102", "w206", "w207", "w301", "w237", "w238", "w158"],  // Describing experiences
        "L073": ["w012", "w007", "w212", "w284", "w285", "w006", "w225"],  // Formal vs informal
        "L074": ["w330", "w331", "w304", "w305", "w303", "w056", "w028"],  // Idioms starter
        "L075": ["w332", "w333", "w302", "w301", "w166", "w237", "w238"],  // Dialect Easter eggs
        "L076": ["w028", "w046", "w222", "w056", "w304", "w307", "w068"],  // Culture: coffee/weddings
        "L077": ["w175", "w176", "w177", "w178", "w338", "w116", "w212"],  // Writing short messages
        "L078": ["w115", "w339", "w030", "w293", "w155", "w302", "w301"],  // Reading sprint
        "L079": ["w021", "w332", "w333", "w293", "w164", "w001", "w160"],  // Speaking sprint
        "L080": ["w115", "w102", "w012", "w330", "w332", "w028", "w175", "w021"],  // A2 final review

        // Unit 9 — B1 Grammar & Narrative
        "L081": ["w280", "w281", "w020", "w154", "w155", "w156", "w327"],  // Subjunctive intro
        "L082": ["w313", "w314", "w315", "w316", "w317", "w102", "w206"],  // Narratives in past
        "L083": ["w208", "w245", "w155", "w293", "w248", "w249", "w299"],  // Reported speech
        "L084": ["w155", "w297", "w299", "w319", "w259", "w260", "w191", "w192"],  // Arguments/opinions
        "L085": ["w152", "w153", "w154", "w155", "w156", "w299", "w318"],  // Plans + reasons
        "L086": ["w110", "w111", "w274", "w275", "w276", "w277", "w278", "w279"],  // Work & career
        "L087": ["w114", "w115", "w116", "w117", "w118", "w119", "w302"],  // Learning & study
        "L088": ["w028", "w068", "w307", "w301", "w237", "w238", "w304"],  // Culture pack
        "L089": ["w247", "w293", "w294", "w155", "w245", "w160", "w164"],  // Listening longer
        "L090": ["w280", "w313", "w208", "w155", "w152", "w110", "w114", "w028"],  // Review

        // Unit 10 — B1 Communication
        "L091": ["w155", "w297", "w299", "w319", "w191", "w192", "w245"],  // Debate basics
        "L092": ["w340", "w119", "w175", "w176", "w339", "w302", "w301"],  // Media & tech
        "L093": ["w306", "w129", "w131", "w134", "w135", "w307", "w239"],  // Health & lifestyle
        "L094": ["w231", "w232", "w233", "w234", "w235", "w237", "w238", "w236"],  // Travel deep
        "L095": ["w303", "w222", "w223", "w225", "w300", "w212", "w284"],  // Social situations
        "L096": ["w297", "w319", "w212", "w213", "w285", "w155", "w259"],  // Polite disagreement
        "L097": ["w330", "w331", "w304", "w305", "w303", "w344", "w345"],  // Humor & slang
        "L098": ["w116", "w338", "w176", "w178", "w155", "w296", "w297"],  // Writing longer messages
        "L099": ["w115", "w339", "w030", "w293", "w302", "w301", "w155"],  // Reading sprint
        "L100": ["w155", "w340", "w306", "w231", "w303", "w297", "w116", "w115"],  // Review

        // Unit 11 — B1 Real World
        "L101": ["w174", "w173", "w283", "w282", "w281", "w229", "w230"],  // Services & bureaucracy
        "L102": ["w268", "w029", "w269", "w270", "w276", "w140", "w283"],  // Housing & contracts
        "L103": ["w140", "w173", "w276", "w137", "w138", "w139", "w141"],  // Money & budgeting
        "L104": ["w303", "w304", "w222", "w056", "w051", "w052", "w225"],  // Relationships
        "L105": ["w307", "w061", "w062", "w063", "w068", "w347", "w307"],  // Food culture
        "L106": ["w144", "w145", "w146", "w344", "w240", "w239", "w242"],  // Sports & leisure
        "L107": ["w166", "w167", "w076", "w268", "w171", "w170", "w120"],  // City life
        "L108": ["w091", "w092", "w093", "w094", "w095", "w096", "w308", "w309"],  // Nature & weather
        "L109": ["w247", "w293", "w294", "w245", "w155", "w160", "w164"],  // Listening longer
        "L110": ["w174", "w268", "w140", "w303", "w307", "w144", "w166", "w091"],  // Review

        // Unit 12 — B1 Mastery
        "L111": ["w206", "w207", "w208", "w211", "w301", "w303", "w102"],  // Storytelling challenge
        "L112": ["w001", "w160", "w164", "w225", "w300", "w141", "w050"],  // Real dialogues
        "L113": ["w330", "w331", "w304", "w305", "w287", "w288", "w289"],  // Idioms & phrases
        "L114": ["w252", "w253", "w254", "w255", "w256", "w257", "w258"],  // Case accuracy drills
        "L115": ["w010", "w011", "w012", "w199", "w200", "w334", "w335"],  // Clitic accuracy drills
        "L116": ["w021", "w332", "w333", "w293", "w164", "w160", "w300"],  // Speaking challenge
        "L117": ["w115", "w339", "w030", "w302", "w301", "w155", "w293"],  // Reading challenge
        "L118": ["w116", "w338", "w176", "w178", "w296", "w297", "w299"],  // Writing challenge
        "L119": ["w001", "w018", "w051", "w091", "w110", "w180", "w243", "w313"],  // Full review
        "L120": ["w001", "w031", "w051", "w091", "w110", "w152", "w243", "w296", "w313", "w155"],  // B1 final test
    ]

    private static func inferWordIds(from title: String) -> [String] {
        let lowered = title.lowercased()
        if lowered.contains("greeting") || lowered.contains("introduc") {
            return ["w001", "w002", "w003", "w004", "w005", "w006", "w007", "w008", "w009"]
        }
        if lowered.contains("pronoun") || lowered.contains("to be") || lowered.contains("clitic") {
            return ["w010", "w011", "w012", "w013", "w014", "w015", "w016", "w017", "w018"]
        }
        if lowered.contains("number") || lowered.contains("time") {
            return ["w031", "w032", "w033", "w034", "w035", "w036", "w037", "w038", "w039", "w040"]
        }
        if lowered.contains("food") || lowered.contains("coffee") || lowered.contains("ordering") || lowered.contains("market") || lowered.contains("eating") {
            return ["w061", "w062", "w063", "w064", "w065", "w068", "w028", "w046"]
        }
        if lowered.contains("family") || lowered.contains("people") || lowered.contains("relationship") {
            return ["w051", "w052", "w053", "w054", "w055", "w056", "w057", "w058", "w059", "w060"]
        }
        if lowered.contains("direction") {
            return ["w071", "w072", "w073", "w074", "w075", "w076", "w077", "w078"]
        }
        if lowered.contains("weather") || lowered.contains("season") || lowered.contains("nature") {
            return ["w091", "w092", "w093", "w094", "w095", "w096", "w097", "w098", "w099", "w100"]
        }
        if lowered.contains("work") || lowered.contains("study") || lowered.contains("career") {
            return ["w110", "w111", "w112", "w113", "w114", "w115", "w116", "w117"]
        }
        if lowered.contains("transport") || lowered.contains("travel") {
            return ["w120", "w121", "w122", "w123", "w124", "w125", "w126"]
        }
        if lowered.contains("health") || lowered.contains("pharmacy") {
            return ["w129", "w130", "w131", "w132", "w133", "w134", "w135"]
        }
        if lowered.contains("shop") || lowered.contains("buying") {
            return ["w263", "w264", "w265", "w266", "w267", "w137", "w138", "w139"]
        }
        if lowered.contains("hobb") || lowered.contains("sport") || lowered.contains("leisure") {
            return ["w144", "w145", "w146", "w147", "w148", "w149", "w150", "w151"]
        }
        if lowered.contains("home") || lowered.contains("house") || lowered.contains("apartment") || lowered.contains("rent") {
            return ["w268", "w269", "w270", "w271", "w272", "w273", "w029", "w088"]
        }
        if lowered.contains("question") || lowered.contains("negat") {
            return ["w159", "w160", "w161", "w162", "w163", "w164", "w165", "w295"]
        }
        if lowered.contains("place") || lowered.contains("town") || lowered.contains("city") {
            return ["w166", "w167", "w168", "w169", "w170", "w171", "w172", "w173"]
        }
        if lowered.contains("phone") || lowered.contains("message") || lowered.contains("writing") {
            return ["w175", "w176", "w177", "w178", "w338", "w116"]
        }
        if lowered.contains("describe") || lowered.contains("adjective") || lowered.contains("color") {
            return ["w180", "w182", "w189", "w190", "w191", "w192", "w193", "w194", "w195"]
        }
        if lowered.contains("possess") {
            return ["w199", "w200", "w201", "w202", "w203", "w204", "w205"]
        }
        if lowered.contains("past") || lowered.contains("stories") || lowered.contains("narrative") || lowered.contains("imperfect") {
            return ["w105", "w206", "w207", "w208", "w209", "w210", "w211", "w313"]
        }
        if lowered.contains("polite") || lowered.contains("formal") || lowered.contains("request") {
            return ["w212", "w213", "w214", "w006", "w007", "w280", "w281", "w284"]
        }
        if lowered.contains("preposition") || lowered.contains("case") {
            return ["w252", "w253", "w254", "w255", "w256", "w257", "w258"]
        }
        if lowered.contains("connector") || lowered.contains("conjunct") {
            return ["w296", "w297", "w298", "w299", "w318", "w319", "w320"]
        }
        if lowered.contains("compar") {
            return ["w259", "w260", "w261", "w262", "w189", "w190"]
        }
        if lowered.contains("verb") {
            return ["w243", "w244", "w245", "w246", "w247", "w248", "w249", "w250", "w251"]
        }
        if lowered.contains("listen") || lowered.contains("sprint") || lowered.contains("reading") || lowered.contains("speaking") {
            return ["w247", "w293", "w294", "w155", "w245", "w115", "w021"]
        }
        if lowered.contains("review") || lowered.contains("checkpoint") || lowered.contains("final") || lowered.contains("test") {
            return ["w001", "w018", "w051", "w091", "w110", "w180", "w243", "w296"]
        }
        if lowered.contains("opinion") || lowered.contains("debate") || lowered.contains("disagree") || lowered.contains("argument") {
            return ["w155", "w297", "w299", "w319", "w191", "w192", "w245"]
        }
        if lowered.contains("plan") || lowered.contains("future") || lowered.contains("suggest") || lowered.contains("condition") {
            return ["w152", "w153", "w154", "w155", "w156", "w280", "w281"]
        }
        if lowered.contains("idiom") || lowered.contains("humor") || lowered.contains("slang") {
            return ["w330", "w331", "w304", "w305", "w287", "w288"]
        }
        if lowered.contains("culture") || lowered.contains("dialect") {
            return ["w028", "w068", "w307", "w301", "w237", "w304"]
        }
        if lowered.contains("money") || lowered.contains("bank") || lowered.contains("budget") {
            return ["w140", "w173", "w276", "w137", "w138", "w139"]
        }
        if lowered.contains("service") || lowered.contains("bureauc") {
            return ["w174", "w173", "w283", "w282", "w281", "w229"]
        }
        if lowered.contains("media") || lowered.contains("tech") || lowered.contains("news") {
            return ["w340", "w119", "w175", "w176", "w339", "w302"]
        }
        // Fallback: mix of common words across categories
        return ["w001", "w018", "w028", "w051", "w091", "w110", "w155", "w243"]
    }
}

// MARK: - Live Engine

final class ExerciseEngine: ExerciseEngineProtocol, @unchecked Sendable {
    private let allWords: [SeedWordEntry]

    init(bundle: Bundle = .main) {
        self.allWords = Self.loadAllVocabulary(bundle: bundle)
    }

    func generateExercises(for lesson: LessonSummary) async -> [Exercise] {
        let targetWordIds = LessonVocabularyMap.wordIds(
            for: lesson.seedId,
            lessonTitle: lesson.title
        )

        let lessonWords = targetWordIds.compactMap { wId in
            allWords.first { $0.id == wId }
        }

        guard !lessonWords.isEmpty else {
            // Use first 8 words as fallback for any lesson
            let fallback = Array(allWords.prefix(8))
            return generateMixedExercises(from: fallback)
        }

        return generateMixedExercises(from: lessonWords)
    }

    func checkAnswer(_ answer: String, for exercise: Exercise) -> Bool {
        let normalizedAnswer = answer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\u{00eb}", with: "ë") // normalize ë
        let normalizedCorrect = exercise.correctAnswer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // Exact match
        if normalizedAnswer == normalizedCorrect { return true }

        // Handle "x / y" style answers — accept either part
        if normalizedCorrect.contains(" / ") {
            let parts = normalizedCorrect
                .components(separatedBy: " / ")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            if parts.contains(normalizedAnswer) { return true }
        }

        return false
    }

    // MARK: - Exercise Generation

    private func generateMixedExercises(from words: [SeedWordEntry]) -> [Exercise] {
        var exercises: [Exercise] = []
        let shuffled = words.shuffled()
        let pool = allWords // for distractors
        let exerciseCount = min(shuffled.count, 8) // Up to 8 exercises per lesson

        for (index, word) in shuffled.prefix(exerciseCount).enumerated() {
            switch index % 4 {
            case 0:
                exercises.append(makeMCQAlbanianToEnglish(word: word, pool: pool))
            case 1:
                exercises.append(makeMCQEnglishToAlbanian(word: word, pool: pool))
            case 2:
                exercises.append(makeTranslateTextInput(word: word))
            case 3:
                // Try fill-in-blank, fall back to MCQ
                if word.exampleSentence != nil {
                    exercises.append(makeFillInBlank(word: word, pool: pool))
                } else {
                    exercises.append(makeMCQAlbanianToEnglish(word: word, pool: pool))
                }
            default:
                break
            }
        }

        // Add extra fill-in-blank exercises for words with example sentences
        let wordsWithExamples = shuffled.filter { $0.exampleSentence != nil }
        for word in wordsWithExamples.prefix(2) {
            if exercises.count < 10 {
                exercises.append(makeFillInBlank(word: word, pool: pool))
            }
        }

        return exercises.isEmpty ? Exercise.mockExercises : exercises
    }

    private func makeMCQAlbanianToEnglish(word: SeedWordEntry, pool: [SeedWordEntry]) -> Exercise {
        let distractors = pickDistractors(for: word, from: pool, count: 3, useEnglish: true)
        return Exercise(
            type: .multipleChoiceTranslate,
            prompt: "What does '\(word.albanian)' mean?",
            correctAnswer: word.english,
            distractors: distractors,
            explanation: word.exampleSentence.map { "Example: \($0)" },
            xpValue: 10
        )
    }

    private func makeMCQEnglishToAlbanian(word: SeedWordEntry, pool: [SeedWordEntry]) -> Exercise {
        let distractors = pickDistractors(for: word, from: pool, count: 3, useEnglish: false)
        return Exercise(
            type: .multipleChoiceTranslate,
            prompt: "How do you say '\(word.english)' in Albanian?",
            correctAnswer: word.albanian,
            distractors: distractors,
            xpValue: 10
        )
    }

    private func makeTranslateTextInput(word: SeedWordEntry) -> Exercise {
        // Randomly choose direction
        let toAlbanian = Bool.random()
        if toAlbanian {
            return Exercise(
                type: .translateTextInput,
                prompt: "Translate: '\(word.english)'",
                correctAnswer: word.albanian,
                hint: "Type in Albanian",
                xpValue: 15
            )
        } else {
            return Exercise(
                type: .translateTextInput,
                prompt: "Translate: '\(word.albanian)'",
                correctAnswer: word.english,
                hint: "Type in English",
                xpValue: 15
            )
        }
    }

    private func makeFillInBlank(word: SeedWordEntry, pool: [SeedWordEntry]) -> Exercise {
        guard let sentence = word.exampleSentence, let translation = word.exampleTranslation else {
            return makeMCQAlbanianToEnglish(word: word, pool: pool)
        }
        let blank = sentence.replacingOccurrences(of: word.albanian, with: "___")
        // Only create fill-in-blank if we actually replaced something
        guard blank != sentence else {
            return makeMCQAlbanianToEnglish(word: word, pool: pool)
        }
        let distractors = pickDistractors(for: word, from: pool, count: 3, useEnglish: false)
        return Exercise(
            type: .fillInBlank,
            prompt: "\(blank) (\(translation))",
            correctAnswer: word.albanian,
            distractors: distractors,
            xpValue: 12
        )
    }

    private func pickDistractors(
        for word: SeedWordEntry,
        from pool: [SeedWordEntry],
        count: Int,
        useEnglish: Bool
    ) -> [String] {
        let candidates = pool.filter { $0.id != word.id }
        let shuffled = candidates.shuffled()
        let picked = shuffled.prefix(count)
        return picked.map { useEnglish ? $0.english : $0.albanian }
    }

    // MARK: - Load Vocabulary

    private static func loadAllVocabulary(bundle: Bundle) -> [SeedWordEntry] {
        guard let url = bundle.url(forResource: "a1_vocabulary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([SeedWordEntry].self, from: data) else {
            return SeedWordEntry.fallback
        }
        return words.isEmpty ? SeedWordEntry.fallback : words
    }
}

// MARK: - Seed Word Entry (lightweight decode-only)

struct SeedWordEntry: Decodable, Sendable {
    let id: String
    let albanian: String
    let english: String
    let cefrLevel: String
    let partOfSpeech: String
    let gender: String?
    let verbClass: String?
    let exampleSentence: String?
    let exampleTranslation: String?
    let frequency: Int?

    static let fallback: [SeedWordEntry] = [
        SeedWordEntry(id: "w001", albanian: "mirëdita", english: "good day / hello", cefrLevel: "a1", partOfSpeech: "interjection", gender: nil, verbClass: nil, exampleSentence: "Mirëdita! Si jeni?", exampleTranslation: "Good day! How are you?", frequency: 1),
        SeedWordEntry(id: "w005", albanian: "mirupafshim", english: "goodbye", cefrLevel: "a1", partOfSpeech: "interjection", gender: nil, verbClass: nil, exampleSentence: nil, exampleTranslation: nil, frequency: 5),
        SeedWordEntry(id: "w006", albanian: "faleminderit", english: "thank you", cefrLevel: "a1", partOfSpeech: "interjection", gender: nil, verbClass: nil, exampleSentence: nil, exampleTranslation: nil, frequency: 6),
        SeedWordEntry(id: "w008", albanian: "po", english: "yes", cefrLevel: "a1", partOfSpeech: "particle", gender: nil, verbClass: nil, exampleSentence: nil, exampleTranslation: nil, frequency: 8),
        SeedWordEntry(id: "w009", albanian: "jo", english: "no", cefrLevel: "a1", partOfSpeech: "particle", gender: nil, verbClass: nil, exampleSentence: nil, exampleTranslation: nil, frequency: 9),
        SeedWordEntry(id: "w018", albanian: "jam", english: "I am / to be (1st sg)", cefrLevel: "a1", partOfSpeech: "verb", gender: nil, verbClass: "irregular", exampleSentence: "Unë jam shqiptar.", exampleTranslation: "I am Albanian.", frequency: 18),
        SeedWordEntry(id: "w019", albanian: "kam", english: "I have / to have (1st sg)", cefrLevel: "a1", partOfSpeech: "verb", gender: nil, verbClass: "irregular", exampleSentence: "Unë kam një libër.", exampleTranslation: "I have a book.", frequency: 19),
        SeedWordEntry(id: "w026", albanian: "ujë", english: "water", cefrLevel: "a1", partOfSpeech: "noun", gender: "m", verbClass: nil, exampleSentence: nil, exampleTranslation: nil, frequency: 26),
    ]
}

// MARK: - Mock Engine

final class MockExerciseEngine: ExerciseEngineProtocol, @unchecked Sendable {
    func generateExercises(for lesson: LessonSummary) async -> [Exercise] {
        return Exercise.mockExercises
    }

    func checkAnswer(_ answer: String, for exercise: Exercise) -> Bool {
        return answer.lowercased() == exercise.correctAnswer.lowercased()
    }
}

// MARK: - Mock Data

extension Exercise {
    static let mockExercises: [Exercise] = [
        Exercise(
            type: .multipleChoiceTranslate,
            prompt: "What does 'mirëdita' mean?",
            correctAnswer: "good day / hello",
            distractors: ["good night", "goodbye", "please"],
            explanation: "'Mirëdita' literally means 'good day' and is the standard daytime greeting.",
            xpValue: 10
        ),
        Exercise(
            type: .multipleChoiceTranslate,
            prompt: "How do you say 'thank you' in Albanian?",
            correctAnswer: "faleminderit",
            distractors: ["mirupafshim", "ju lutem", "po"],
            xpValue: 10
        ),
        Exercise(
            type: .translateTextInput,
            prompt: "Translate: 'I have water'",
            correctAnswer: "kam ujë",
            hint: "Use 'kam' for 'I have'",
            explanation: "'Kam' means 'I have' (1st person singular of the verb 'to have').",
            xpValue: 15
        ),
        Exercise(
            type: .fillInBlank,
            prompt: "Unë ___ student. (I am a student)",
            correctAnswer: "jam",
            distractors: ["kam", "dua", "flas"],
            explanation: "'Jam' means 'I am'. Albanian verb 'to be' is 'jam/je/është'.",
            xpValue: 10
        ),
    ]
}
