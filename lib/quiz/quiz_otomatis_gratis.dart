import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../baca_file_materi.dart';
import 'quiz_groq.dart';
import 'quiz_screens.dart';

/// ===================== LAYAR KUIS OTOMATIS (GRATIS, GROQ) =====================
/// Tampilan sama seperti QuizOtomatisScreen, tetapi soal dibuat lewat
/// GroqQuizGenerator (gratis), bukan Firebase AI.
class QuizOtomatisGratisScreen extends StatefulWidget {
  final String mataKuliah; // opsional, untuk mengisi otomatis
  const QuizOtomatisGratisScreen({super.key, this.mataKuliah = ''});

  @override
  State<QuizOtomatisGratisScreen> createState() =>
      _QuizOtomatisGratisScreenState();
}

class _QuizOtomatisGratisScreenState extends State<QuizOtomatisGratisScreen> {
  late final TextEditingController _mk =
      TextEditingController(text: widget.mataKuliah);
  int _jumlah = 20;
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

      final soal = await GroqQuizGenerator.generate(
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
      _pesan('Gagal: ${e.toString().replaceFirst('Exception: ', '')}');
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
                  children: [10, 20, 30, 50]
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