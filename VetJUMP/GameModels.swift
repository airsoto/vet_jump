import Foundation

enum FruitKind: String, CaseIterable, Codable {
    case apple, banana, grapes, lemon, broccoli

    var emoji: String {
        switch self { case .apple: "🍎"; case .banana: "🍌"; case .grapes: "🍇"; case .lemon: "🍋"; case .broccoli: "🥦" }
    }
}

enum ExamKind: Equatable {
    case rescue, fallRescue(attempt: Int), broccoli, final

    var questionCount: Int {
        switch self {
        case .fallRescue(let attempt): return attempt == 1 ? 1 : attempt == 2 ? 3 : 5
        case .final: return 20
        case .rescue, .broccoli: return 10
        }
    }

    var requiredCorrect: Int {
        switch self {
        case .fallRescue(let attempt): return attempt == 1 ? 1 : attempt == 2 ? 2 : 4
        case .rescue: return 7
        case .broccoli: return 8
        case .final: return 15
        }
    }
    var usesHardQuestions: Bool { if case .fallRescue(let attempt) = self { return attempt == 1 }; return false }

    static func fallRescueForAttempt(_ attempt: Int) -> ExamKind { .fallRescue(attempt: min(max(attempt, 1), 3)) }
}

struct ECVIMBank: Decodable { let preguntas: [ClinicalQuestion] }

struct ClinicalQuestion: Decodable, Identifiable {
    let id: Int
    let area: String
    let dificultad: String
    let enunciado: String
    let opciones: [String: String]
    let respuestaCorrecta: String
    let explicacion: Explanation

    enum CodingKeys: String, CodingKey { case id, area, dificultad, enunciado, opciones, explicacion; case respuestaCorrecta = "respuesta_correcta" }
}

struct Explanation: Decodable { let porQueCorrecta: String; enum CodingKeys: String, CodingKey { case porQueCorrecta = "por_que_correcta" } }

struct PlayerProgress: Codable {
    var selectedCharacter = 0
    var unlockedLevel = 1
    var completedLevel = 0
    var currentLevel = 1
    var platform = 0
    var score = 0
    var lives = 1
    var answeredQuestionIDs = Set<Int>()
    var subjectStats = [String: SubjectStat]()
    var infinitePlatform = 0
    var infiniteScore = 0

    var hasCompletedAllLevels: Bool { completedLevel >= 5 }

    enum CodingKeys: String, CodingKey { case selectedCharacter, unlockedLevel, completedLevel, currentLevel, platform, score, lives, answeredQuestionIDs, subjectStats, infinitePlatform, infiniteScore }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedCharacter = try container.decodeIfPresent(Int.self, forKey: .selectedCharacter) ?? 0
        unlockedLevel = try container.decodeIfPresent(Int.self, forKey: .unlockedLevel) ?? 1
        completedLevel = try container.decodeIfPresent(Int.self, forKey: .completedLevel) ?? 0
        currentLevel = try container.decodeIfPresent(Int.self, forKey: .currentLevel) ?? 1
        platform = try container.decodeIfPresent(Int.self, forKey: .platform) ?? 0
        score = try container.decodeIfPresent(Int.self, forKey: .score) ?? 0
        lives = try container.decodeIfPresent(Int.self, forKey: .lives) ?? 1
        answeredQuestionIDs = try container.decodeIfPresent(Set<Int>.self, forKey: .answeredQuestionIDs) ?? []
        subjectStats = try container.decodeIfPresent([String: SubjectStat].self, forKey: .subjectStats) ?? [:]
        infinitePlatform = try container.decodeIfPresent(Int.self, forKey: .infinitePlatform) ?? 0
        infiniteScore = try container.decodeIfPresent(Int.self, forKey: .infiniteScore) ?? 0
    }
}

struct SubjectStat: Codable { var correct = 0; var total = 0 }

final class ProgressStore {
    static let shared = ProgressStore()
    private let key = "VetJUMP.progress.v1"
    private init() {}
    func load() -> PlayerProgress { guard let data = UserDefaults.standard.data(forKey: key), let progress = try? JSONDecoder().decode(PlayerProgress.self, from: data) else { return PlayerProgress() }; return progress }
    func save(_ progress: PlayerProgress) { guard let data = try? JSONEncoder().encode(progress) else { return }; UserDefaults.standard.set(data, forKey: key) }
}
