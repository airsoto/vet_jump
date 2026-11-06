import Foundation

final class QuestionService {
    private let questions: [ClinicalQuestion]
    init() {
        guard let url = Bundle.main.url(forResource: "ecvim", withExtension: "json"), let data = try? Data(contentsOf: url), let bank = try? JSONDecoder().decode(ECVIMBank.self, from: data) else { questions = []; return }
        questions = bank.preguntas
    }

    func exam(kind: ExamKind, level: Int, excluding usedIDs: Set<Int>) -> [ClinicalQuestion] {
        let difficultyOrder = ["media", "alta", "muy alta"]
        let preferred = difficultyOrder[min(max(level - 1, 0), difficultyOrder.count - 1)]
        let fresh = questions.filter { !usedIDs.contains($0.id) }
        let pool = fresh.isEmpty ? questions : fresh
        let difficulty = kind.usesHardQuestions ? "muy alta" : preferred
        let prioritised = pool.filter { $0.dificultad.lowercased() == difficulty }
        let source = prioritised.count >= kind.questionCount ? prioritised : pool
        return Array(source.shuffled().prefix(kind.questionCount))
    }
}
