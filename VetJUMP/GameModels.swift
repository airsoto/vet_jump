import Foundation

enum FruitKind: String, CaseIterable, Codable {
    case apple, banana, grapes, lemon, broccoli

    var emoji: String {
        switch self { case .apple: "🍎"; case .banana: "🍌"; case .grapes: "🍇"; case .lemon: "🍋"; case .broccoli: "🥦" }
    }
}

enum ExamKind {
    case rescue, broccoli, final

    var questionCount: Int { switch self { case .final: 20; case .rescue, .broccoli: 10 } }
    var requiredCorrect: Int { switch self { case .rescue: 7; case .broccoli: 8; case .final: 15 } }
    var title: String { switch self { case .rescue: "RESCATE CLÍNICO"; case .broccoli: "EXAMEN BRÓCOLI"; case .final: "EXAMEN FINAL" } }
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
    var currentLevel = 1
    var platform = 0
    var score = 0
    var lives = 1
    var answeredQuestionIDs = Set<Int>()
    var subjectStats = [String: SubjectStat]()
    var infinitePlatform = 0
    var infiniteScore = 0
}

struct SubjectStat: Codable { var correct = 0; var total = 0 }

final class ProgressStore {
    static let shared = ProgressStore()
    private let key = "VetJUMP.progress.v1"
    private init() {}
    func load() -> PlayerProgress { guard let data = UserDefaults.standard.data(forKey: key), let progress = try? JSONDecoder().decode(PlayerProgress.self, from: data) else { return PlayerProgress() }; return progress }
    func save(_ progress: PlayerProgress) { guard let data = try? JSONEncoder().encode(progress) else { return }; UserDefaults.standard.set(data, forKey: key) }
}
