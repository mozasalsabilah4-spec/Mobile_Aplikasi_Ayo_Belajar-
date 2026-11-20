enum QuizType { pilihanGanda, essai }

class QuizQuestion {
  final QuizType type;
  final String question;
  final List<String> options; // kosong untuk essai
  final int correctIndex; // hanya untuk pilihan ganda
  final String answerKey; // kunci jawaban (essai)
  final String explanation;

  const QuizQuestion({
    required this.type,
    required this.question,
    this.options = const [],
    this.correctIndex = 0,
    this.answerKey = '',
    this.explanation = '',
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> j) {
    final isMcq = (j['type'] ?? 'pilihan_ganda').toString() == 'pilihan_ganda';
    return QuizQuestion(
      type: isMcq ? QuizType.pilihanGanda : QuizType.essai,
      question: (j['question'] ?? '').toString().trim(),
      options: ((j['options'] ?? []) as List)
          .map((e) => e.toString().trim())
          .toList(),
      correctIndex: (j['correctIndex'] as num?)?.toInt() ?? 0,
      answerKey: (j['answerKey'] ?? '').toString().trim(),
      explanation: (j['explanation'] ?? '').toString().trim(),
    );
  }

  QuizQuestion copyWithOptions(List<String> newOptions, int newCorrect) {
    return QuizQuestion(
      type: type,
      question: question,
      options: newOptions,
      correctIndex: newCorrect,
      answerKey: answerKey,
      explanation: explanation,
    );
  }
}

class EssayResult {
  final bool correct;
  final String feedback;
  const EssayResult({required this.correct, required this.feedback});
}