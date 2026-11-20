import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'quiz_models.dart';

class QuizGenerator {
  // Ganti jika model ini tidak tersedia di proyek Firebase Anda.
  static const String _modelName = 'gemini-2.5-flash';

  // Jika kode AI Anda yang lama memakai FirebaseAI.vertexAI(),
  // ganti googleAI() di bawah menjadi vertexAI().
  static GenerativeModel _model(Schema schema) {
    return FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: schema,
        temperature: 0.8,
      ),
    );
  }

  static final Schema _questionSchema = Schema.array(
    items: Schema.object(properties: {
      'type': Schema.enumString(enumValues: ['pilihan_ganda', 'essai']),
      'question': Schema.string(),
      'options': Schema.array(items: Schema.string()),
      'correctIndex': Schema.integer(),
      'answerKey': Schema.string(),
      'explanation': Schema.string(),
    }),
  );

  static String _cut(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  /// Membuat [jumlah] soal. [persenPilihanGanda] 0.0 - 1.0
  static Future<List<QuizQuestion>> generate({
    required String judul,
    required String materi,
    required int jumlah,
    required double persenPilihanGanda,
    void Function(int done, int total)? onProgress,
  }) async {
    const batch = 10;
    final targetMcq = (jumlah * persenPilihanGanda).round();
    final targetEssay = jumlah - targetMcq;
    int mcqDone = 0, essayDone = 0, attempts = 0;
    final maxAttempts = (jumlah / batch).ceil() * 3;
    final all = <QuizQuestion>[];
    final seen = <String>{};
    Object? lastError;

    while (all.length < jumlah && attempts < maxAttempts) {
      attempts++;
      final needMcq = (targetMcq - mcqDone).clamp(0, batch).toInt();
      final needEssay =
          (targetEssay - essayDone).clamp(0, batch - needMcq).toInt();
      if (needMcq + needEssay == 0) break;

      final previous = all.reversed
          .take(40)
          .map((q) => '- ${_cut(q.question, 80)}')
          .join('\n');

      final prompt = '''
Kamu adalah pembuat soal kuis untuk mahasiswa. Buat soal dalam Bahasa Indonesia.

Judul materi: $judul
Materi:
"""
${_cut(materi, 30000)}
"""

Buat TEPAT $needMcq soal pilihan ganda dan $needEssay soal essai singkat.

Aturan pilihan ganda:
- type = "pilihan_ganda", options berisi tepat 4 pilihan (tanpa awalan A/B/C/D).
- correctIndex = nomor jawaban benar (0 sampai 3).
- Pengecoh harus masuk akal dan boleh berasal dari konsep lain yang berkaitan dengan topik, tidak harus dari teks materi.
- explanation: jelaskan mengapa jawaban benar itu benar dan mengapa pengecoh utama salah.

Aturan essai:
- type = "essai", options = [], correctIndex = 0.
- answerKey = jawaban singkat yang benar (1-2 kalimat).
- explanation = penjelasan singkat jawabannya.

Variasikan tingkat kesulitan (ingatan, pemahaman, penerapan).
JANGAN mengulang soal berikut:
${previous.isEmpty ? '(belum ada)' : previous}
''';

      try {
        final res = await _model(_questionSchema)
            .generateContent([Content.text(prompt)]);
        final raw = (res.text ?? '[]')
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final list = jsonDecode(raw) as List;

        for (final item in list) {
          if (item is! Map) continue;
          var q = QuizQuestion.fromJson(Map<String, dynamic>.from(item));
          if (q.question.isEmpty) continue;
          final key = q.question.toLowerCase();
          if (seen.contains(key)) continue;

          if (q.type == QuizType.pilihanGanda) {
            if (q.options.length != 4 ||
                q.correctIndex < 0 ||
                q.correctIndex > 3 ||
                mcqDone >= targetMcq) {
              continue;
            }
            // acak posisi jawaban agar tidak selalu di pilihan yang sama
            final correctText = q.options[q.correctIndex];
            final shuffled = [...q.options]..shuffle();
            q = q.copyWithOptions(shuffled, shuffled.indexOf(correctText));
            mcqDone++;
          } else {
            if (q.answerKey.isEmpty || essayDone >= targetEssay) continue;
            essayDone++;
          }
          seen.add(key);
          all.add(q);
          onProgress?.call(all.length, jumlah);
        }
      } catch (e) {
        lastError = e;
      }
    }

    if (all.isEmpty && lastError != null) throw lastError;
    all.shuffle();
    return all;
  }

  /// Memeriksa jawaban essai memakai AI. Jika gagal, pakai pencocokan kata kunci.
  static Future<EssayResult> gradeEssay({
    required QuizQuestion q,
    required String userAnswer,
  }) async {
    try {
      final schema = Schema.object(properties: {
        'correct': Schema.boolean(),
        'feedback': Schema.string(),
      });
      final prompt = '''
Periksa jawaban mahasiswa. Nilai benar jika intinya sesuai kunci jawaban,
walaupun kalimatnya berbeda. Jawab dalam Bahasa Indonesia.

Soal: ${q.question}
Kunci jawaban: ${q.answerKey}
Jawaban mahasiswa: $userAnswer

Isi "correct" true/false, dan "feedback" berupa 1-2 kalimat penjelasan
mengapa jawaban itu benar atau apa yang kurang/salah.
''';
      final res =
          await _model(schema).generateContent([Content.text(prompt)]);
      final map = jsonDecode(res.text ?? '{}') as Map<String, dynamic>;
      return EssayResult(
        correct: map['correct'] == true,
        feedback: (map['feedback'] ?? '').toString(),
      );
    } catch (_) {
      return _fallbackGrade(q, userAnswer);
    }
  }

  static EssayResult _fallbackGrade(QuizQuestion q, String answer) {
    Set<String> words(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet();
    final key = words(q.answerKey);
    final ans = words(answer);
    if (key.isEmpty) {
      return const EssayResult(
          correct: false, feedback: 'Tidak dapat memeriksa jawaban.');
    }
    final ratio = key.intersection(ans).length / key.length;
    return EssayResult(
      correct: ratio >= 0.5,
      feedback: ratio >= 0.5
          ? 'Jawabanmu mencakup inti dari kunci jawaban.'
          : 'Jawabanmu belum mencakup inti dari kunci jawaban.',
    );
  }
}