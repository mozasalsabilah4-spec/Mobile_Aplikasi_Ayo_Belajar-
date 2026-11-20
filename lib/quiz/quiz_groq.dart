import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'quiz_models.dart';
import 'quiz_screens.dart';
import 'kuis_tersimpan.dart';

/// ===================== PEMBUAT KUIS GRATIS (GROQ) - VERSI CEPAT =====================
/// Soal dibuat per batch (10 soal) dan beberapa batch dikirim BERSAMAAN.
/// Setiap batch hanya membawa sebagian materi, jadi lebih ringan dan cepat.
class GroqQuizGenerator {
  // >>> GANTI TULISAN DI BAWAH DENGAN API KEY GROQ KAMU (berawalan gsk_) <<<
  static const String _apiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: 'ISI_API_KEY_GROQ_DI_SINI',
  );

  // Jika muncul error "model tidak ditemukan", ganti nama model ini.
  // Daftar model: console.groq.com/docs/models
  // Alternatif yang lebih pintar tapi sedikit lebih lambat: 'openai/gpt-oss-120b'
  static const String _modelName = 'openai/gpt-oss-20b';

  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  static const int _ukuranBatch = 10; // soal per permintaan
  static const int _paralel = 3; // permintaan yang berjalan bersamaan
  static const int _maxKarakterPerBatch = 6000; // materi per permintaan

  static String _cut(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  /// Bagi materi menjadi [n] potongan yang kira-kira sama panjang.
  static List<String> _bagi(String materi, int n) {
    if (n <= 1) return [_cut(materi, _maxKarakterPerBatch)];
    final panjang = (materi.length / n).ceil();
    final hasil = <String>[];
    for (int i = 0; i < n; i++) {
      final mulai = i * panjang;
      if (mulai >= materi.length) break;
      final akhir = math.min(mulai + panjang, materi.length);
      hasil.add(_cut(materi.substring(mulai, akhir), _maxKarakterPerBatch));
    }
    return hasil;
  }

  /// Satu permintaan ke Groq. Jika kena batas (429), menunggu sesuai
  /// anjuran server lalu mencoba lagi (maksimal 3 kali).
  static Future<List<QuizQuestion>> _satuBatch({
    required String mataKuliah,
    required String materi,
    required int butuh,
    List<String> hindari = const [],
  }) async {
    final daftarHindari =
        hindari.take(40).map((s) => '- ${_cut(s, 80)}').join('\n');

    final prompt = '''
Kamu pembuat soal kuis untuk mahasiswa. Gunakan Bahasa Indonesia.

Mata kuliah: $mataKuliah
Materi:
"""
$materi
"""

Buat TEPAT $butuh soal PILIHAN GANDA.
- Sekitar 70% soal diambil langsung dari isi materi.
- Sekitar 30% soal pengayaan: boleh di luar isi materi, tetapi HARUS masih
  termasuk dalam cakupan mata kuliah "$mataKuliah".
- options berisi tepat 4 pilihan (tanpa awalan A/B/C/D), pengecoh harus masuk akal.
- correctIndex = nomor jawaban benar (0 sampai 3).
- explanation: jelaskan mengapa jawaban benar itu benar, dan mengapa pilihan
  lain salah. Singkat dan jelas, 2-4 kalimat.
- Variasikan tingkat kesulitan.

JANGAN mengulang soal berikut:
${daftarHindari.isEmpty ? '(belum ada)' : daftarHindari}

Balas HANYA dengan satu objek JSON berformat:
{"soal": [{"question": "...", "options": ["...","...","...","..."], "correctIndex": 0, "explanation": "..."}]}
''';

    for (int percobaan = 0; percobaan < 3; percobaan++) {
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _modelName,
              'temperature': 0.7,
              'max_tokens': 6000,
              'reasoning_effort': 'low', // khusus model gpt-oss, supaya cepat
              'response_format': {'type': 'json_object'},
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'Kamu hanya membalas dengan JSON valid, tanpa teks lain.',
                },
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 60));

      final body = utf8.decode(res.bodyBytes);

      if (res.statusCode == 401) {
        throw _GroqFatal('API key Groq tidak valid. Periksa kembali key-nya.');
      }
      if (res.statusCode == 404) {
        throw _GroqFatal(
            'Model "$_modelName" tidak ditemukan. Ganti _modelName di quiz_groq.dart.');
      }
      if (res.statusCode == 429) {
        if (percobaan == 2) {
          throw Exception(
              'Batas pemakaian gratis Groq tercapai. Tunggu sebentar lalu coba lagi.');
        }
        final tunggu = int.tryParse(res.headers['retry-after'] ?? '') ?? 10;
        await Future.delayed(Duration(seconds: tunggu.clamp(2, 30).toInt()));
        continue;
      }
      if (res.statusCode != 200) {
        throw Exception('Groq error ${res.statusCode}: $body');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final content = data['choices'][0]['message']['content'] as String;
      final raw =
          content.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(raw);
      final List list = decoded is List ? decoded : (decoded['soal'] as List);

      final hasil = <QuizQuestion>[];
      for (final item in list) {
        if (item is! Map) continue;
        var q = QuizQuestion.fromJson(Map<String, dynamic>.from(item));
        if (q.question.isEmpty || q.options.length != 4) continue;
        if (q.correctIndex < 0 || q.correctIndex > 3) continue;

        // acak posisi jawaban
        final benar = q.options[q.correctIndex];
        final acak = [...q.options]..shuffle();
        q = q.copyWithOptions(acak, acak.indexOf(benar));
        hasil.add(q);
      }
      return hasil;
    }
    return [];
  }

  static Future<List<QuizQuestion>> generate({
    required String mataKuliah,
    required String materi,
    required int jumlah,
    void Function(int done, int total)? onProgress,
  }) async {
    if (_apiKey.startsWith('ISI_API_KEY')) {
      throw Exception(
          'API key Groq belum diisi. Buka quiz_groq.dart dan isi _apiKey.');
    }

    // 1) Susun daftar batch, misalnya 30 soal -> [10, 10, 10]
    final ukuran = <int>[];
    int sisa = jumlah;
    while (sisa > 0) {
      final s = math.min(sisa, _ukuranBatch);
      ukuran.add(s);
      sisa -= s;
    }
    final potongan = _bagi(materi, ukuran.length);
    final hasil = List.generate(ukuran.length, (_) => <QuizQuestion>[]);

    int terkumpul = 0;
    int berikut = 0;
    Object? lastError;

    // 2) Beberapa "pekerja" mengambil batch secara bergantian dan bersamaan
    Future<void> pekerja() async {
      while (true) {
        final i = berikut++;
        if (i >= ukuran.length) return;
        try {
          hasil[i] = await _satuBatch(
            mataKuliah: mataKuliah,
            materi: potongan[i % potongan.length],
            butuh: ukuran[i],
          );
          terkumpul += hasil[i].length;
          onProgress?.call(math.min(terkumpul, jumlah), jumlah);
        } on _GroqFatal {
          rethrow;
        } catch (e) {
          lastError = e;
        }
      }
    }

    try {
      await Future.wait(
        List.generate(
          math.min(_paralel, ukuran.length),
          (_) => pekerja(),
        ),
      );
    } on _GroqFatal catch (e) {
      throw Exception(e.pesan);
    }

    // 3) Gabungkan dan buang soal kembar
    final semua = <QuizQuestion>[];
    final seen = <String>{};
    for (final daftar in hasil) {
      for (final q in daftar) {
        final key = q.question.toLowerCase();
        if (seen.add(key) && semua.length < jumlah) semua.add(q);
      }
    }

    // 4) Jika kurang (ada batch gagal / soal kembar), tambal maksimal 2 kali
    int tambal = 0;
    while (semua.length < jumlah && tambal < 2) {
      tambal++;
      try {
        final baru = await _satuBatch(
          mataKuliah: mataKuliah,
          materi: _cut(materi, _maxKarakterPerBatch),
          butuh: math.min(jumlah - semua.length, _ukuranBatch),
          hindari: semua.map((q) => q.question).toList().reversed.toList(),
        );
        for (final q in baru) {
          final key = q.question.toLowerCase();
          if (seen.add(key) && semua.length < jumlah) semua.add(q);
        }
        onProgress?.call(semua.length, jumlah);
      } on _GroqFatal catch (e) {
        throw Exception(e.pesan);
      } catch (e) {
        lastError = e;
      }
    }

    if (semua.isEmpty && lastError != null) throw lastError!;
    return semua;
  }
}

class _GroqFatal implements Exception {
  final String pesan;
  _GroqFatal(this.pesan);
}

/// ===================== KUIS GRATIS DARI TEKS MATERI (dipanggil dari Buat Kartu) =====================
Future<void> bukaKuisGratisDariMateri(
  BuildContext context, {
  required String mataKuliah,
  required String materi,
}) async {
  if (mataKuliah.trim().isEmpty || materi.trim().length < 50) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Isi nama mata kuliah dan unggah/ketik materi dulu.'),
      ),
    );
    return;
  }

  final jumlah = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Berapa soal yang ingin dibuat?',
                style: Theme.of(c)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Pilihan ganda dengan penjelasan di setiap soal.',
                style:
                    TextStyle(color: Theme.of(c).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [10, 20, 30, 50]
                  .map((n) => ActionChip(
                        label: Text('$n soal'),
                        onPressed: () => Navigator.pop(c, n),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );

  if (jumlah == null || !context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => QuizDariMateriGratisScreen(
        mataKuliah: mataKuliah.trim(),
        materi: materi,
        jumlah: jumlah,
      ),
    ),
  );
}

class QuizDariMateriGratisScreen extends StatefulWidget {
  final String mataKuliah;
  final String materi;
  final int jumlah;
  const QuizDariMateriGratisScreen({
    super.key,
    required this.mataKuliah,
    required this.materi,
    required this.jumlah,
  });

  @override
  State<QuizDariMateriGratisScreen> createState() =>
      _QuizDariMateriGratisScreenState();
}

class _QuizDariMateriGratisScreenState
    extends State<QuizDariMateriGratisScreen> {
  int _done = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mulai();
  }

  Future<void> _mulai() async {
    try {
      final soal = await GroqQuizGenerator.generate(
        mataKuliah: widget.mataKuliah,
        materi: widget.materi,
        jumlah: widget.jumlah,
        onProgress: (d, t) {
          if (mounted) setState(() => _done = d);
        },
      );
      if (!mounted) return;
      if (soal.isEmpty) throw Exception('Soal tidak berhasil dibuat.');
      // (BARU) simpan ke mata kuliah, jadi tetap ada di beranda walau kuis tidak dilanjutkan
      KuisStore.simpan(mataKuliah: widget.mataKuliah, soal: soal);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => QuizPlayScreen(questions: soal)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Membuat Kuis')),
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: cs.error),
                      const SizedBox(height: 16),
                      Text('Gagal membuat soal',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _done = 0;
                          });
                          _mulai();
                        },
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.auto_awesome,
                            size: 48, color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(height: 28),
                      Text('AI sedang membuat soal...',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(widget.mataKuliah,
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: _done == 0
                              ? null
                              : (_done / widget.jumlah).clamp(0.0, 1.0),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('$_done dari ${widget.jumlah} soal',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 24),
                      Text('Mohon tunggu, jangan tutup aplikasi.',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}