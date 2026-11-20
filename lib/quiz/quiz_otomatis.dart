import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';

import '../baca_file_materi.dart';
import 'quiz_models.dart';
import 'quiz_screens.dart';

/// ===================== PEMBUAT KUIS OTOMATIS =====================
class _AutoQuizGenerator {
  // Ganti jika model ini ditolak di proyek Firebase Anda.
  static const String _modelName = 'gemini-3.8-flash';

  static final Schema _schema = Schema.array(
    items: Schema.object(properties: {
      'question': Schema.string(),
      'options': Schema.array(items: Schema.string()),
      'correctIndex': Schema.integer(),
      'explanation': Schema.string(),
    }),
  );

  static GenerativeModel _model() {
    // Jika kode AI lama Anda memakai vertexAI(), ganti googleAI() jadi vertexAI().
    return FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: _schema,
        temperature: 0.8,
      ),
    );
  }

  static String _cut(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  static Future<List<QuizQuestion>> generate({
    required String mataKuliah,
    required String materi,
    required int jumlah,
    void Function(int done, int total)? onProgress,
  }) async {
    const batch = 25; // (BARU) sebelumnya 10, supaya permintaan lebih sedikit
    final all = <QuizQuestion>[];
    final seen = <String>{};
    final maxAttempts = (jumlah / batch).ceil() * 3;
    int attempts = 0;
    Object? lastError;

    while (all.length < jumlah && attempts < maxAttempts) {
      attempts++;
      // (BARU) jeda antar permintaan agar tidak kena batas 5 per menit
      if (attempts > 1) {
        await Future.delayed(const Duration(seconds: 13));
      }
      final butuh = (jumlah - all.length).clamp(1, batch).toInt();
      final previous = all.reversed
          .take(40)
          .map((q) => '- ${_cut(q.question, 80)}')
          .join('\n');

      final prompt = '''
Kamu pembuat soal kuis untuk mahasiswa. Gunakan Bahasa Indonesia.

Mata kuliah: $mataKuliah
Materi:
"""
${_cut(materi, 30000)}
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
${previous.isEmpty ? '(belum ada)' : previous}
''';

      try {
        final res = await _model().generateContent([Content.text(prompt)]);
        final raw = (res.text ?? '[]')
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final list = jsonDecode(raw) as List;

        for (final item in list) {
          if (item is! Map) continue;
          var q = QuizQuestion.fromJson(Map<String, dynamic>.from(item));
          if (q.question.isEmpty || q.options.length != 4) continue;
          if (q.correctIndex < 0 || q.correctIndex > 3) continue;
          final key = q.question.toLowerCase();
          if (seen.contains(key) || all.length >= jumlah) continue;

          // acak posisi jawaban
          final benar = q.options[q.correctIndex];
          final acak = [...q.options]..shuffle();
          q = q.copyWithOptions(acak, acak.indexOf(benar));

          seen.add(key);
          all.add(q);
          onProgress?.call(all.length, jumlah);
        }
      } catch (e) {
        lastError = e;
        // (BARU) kalau kena batas kuota, tunggu lebih lama sebelum mencoba lagi
        if (e.toString().toLowerCase().contains('quota')) {
          await Future.delayed(const Duration(seconds: 35));
        }
      }
    }

    if (all.isEmpty && lastError != null) throw lastError;
    return all;
  }
}

/// ===================== LAYAR KUIS OTOMATIS (unggah file langsung) =====================
class QuizOtomatisScreen extends StatefulWidget {
  final String mataKuliah; // opsional, untuk mengisi otomatis
  const QuizOtomatisScreen({super.key, this.mataKuliah = ''});

  @override
  State<QuizOtomatisScreen> createState() => _QuizOtomatisScreenState();
}

class _QuizOtomatisScreenState extends State<QuizOtomatisScreen> {
  late final TextEditingController _mk =
      TextEditingController(text: widget.mataKuliah);
  int _jumlah = 20; // (BARU) sebelumnya 50
  bool _loading = false;
  int _done = 0;
  String _tahap = '';
  String _namaFile = '';

  @override
  void dispose() {
    _mk.dispose();
    super.dispose();
  }

  void _pesan(String t) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _pilihDanBuat() async {
    if (_loading) return;
    if (_mk.text.trim().isEmpty) {
      _pesan('Isi nama mata kuliah dulu.');
      return;
    }
    FocusScope.of(context).unfocus();

    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty || !mounted) return;
      final file = files.first;

      setState(() {
        _loading = true;
        _done = 0;
        _namaFile = file.name;
        _tahap = 'Membaca materi...';
      });

      final teks = await bacaTeksMateri(file);
      if (teks.trim().length < 50) {
        throw Exception('Isi file terlalu sedikit atau tidak terbaca.');
      }
      if (!mounted) return;
      setState(() => _tahap = 'AI sedang membuat soal...');

      final soal = await _AutoQuizGenerator.generate(
        mataKuliah: _mk.text.trim(),
        materi: teks,
        jumlah: _jumlah,
        onProgress: (d, t) {
          if (mounted) setState(() => _done = d);
        },
      );
      if (!mounted) return;
      if (soal.isEmpty) throw Exception('Soal tidak berhasil dibuat.');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => QuizPlayScreen(questions: soal)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _pesan('Gagal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: _loading ? _buildLoading(cs) : _buildForm(cs),
    );
  }

  Widget _buildLoading(ColorScheme cs) {
    return SafeArea(
      child: Center(
        // (BARU) kartu putih agar teks terbaca di atas gradasi
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
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
              Text(_tahap,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(_namaFile,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: _done == 0 ? null : (_done / _jumlah).clamp(0.0, 1.0),
                ),
              ),
              const SizedBox(height: 10),
              Text('$_done dari $_jumlah soal',
                  style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 24),
              Text('Mohon tunggu, jangan tutup aplikasi.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ColorScheme cs) {
    return Column(
      children: [
        // Header gradasi
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 8, 20, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cs.primary, cs.tertiary],
            ),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: cs.onPrimary),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              const SizedBox(height: 8),
              Icon(Icons.auto_awesome, color: cs.onPrimary, size: 36),
              const SizedBox(height: 10),
              Text('Kuis Otomatis',
                  style: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Unggah materi, AI langsung membuat soal pilihan ganda lengkap dengan penjelasan.',
                style: TextStyle(
                    color: cs.onPrimary.withValues(alpha: 0.9), height: 1.35),
              ),
            ],
          ),
        ),
        Expanded(
          // (BARU) kartu putih agar teks terbaca di atas gradasi
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('1. Mata kuliah',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _mk,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Pemrograman Mobile',
                    prefixIcon: const Icon(Icons.school_outlined),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Soal pengayaan akan tetap berada dalam cakupan mata kuliah ini.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 22),
                Text('2. Jumlah soal',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [20, 30, 50, 70, 100]
                      .map((n) => ChoiceChip(
                            label: Text('$n soal'),
                            selected: _jumlah == n,
                            onSelected: (_) => setState(() => _jumlah = n),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 22),
                Text('3. Unggah materi',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Material(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: cs.primary, width: 1.5),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _pilihDanBuat,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Column(
                        children: [
                          Icon(Icons.cloud_upload_outlined,
                              size: 56, color: cs.primary),
                          const SizedBox(height: 12),
                          Text('Ketuk untuk memilih file materi',
                              style: TextStyle(
                                  color: cs.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('PDF, DOCX, PPTX, TXT, MD',
                              style: TextStyle(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Setelah file dipilih, kuis langsung dibuat dan dimulai otomatis.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// ===================== KUIS DARI TEKS MATERI (dipanggil dari Buat Kartu) =====================
Future<void> bukaKuisDariMateri(
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
              children: [20, 30, 50, 70, 100]
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
      builder: (_) => QuizDariMateriScreen(
        mataKuliah: mataKuliah.trim(),
        materi: materi,
        jumlah: jumlah,
      ),
    ),
  );
}

class QuizDariMateriScreen extends StatefulWidget {
  final String mataKuliah;
  final String materi;
  final int jumlah;
  const QuizDariMateriScreen({
    super.key,
    required this.mataKuliah,
    required this.materi,
    required this.jumlah,
  });

  @override
  State<QuizDariMateriScreen> createState() => _QuizDariMateriScreenState();
}

class _QuizDariMateriScreenState extends State<QuizDariMateriScreen> {
  int _done = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mulai();
  }

  Future<void> _mulai() async {
    try {
      final soal = await _AutoQuizGenerator.generate(
        mataKuliah: widget.mataKuliah,
        materi: widget.materi,
        jumlah: widget.jumlah,
        onProgress: (d, t) {
          if (mounted) setState(() => _done = d);
        },
      );
      if (!mounted) return;
      if (soal.isEmpty) throw Exception('Soal tidak berhasil dibuat.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => QuizPlayScreen(questions: soal)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Membuat Kuis')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
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