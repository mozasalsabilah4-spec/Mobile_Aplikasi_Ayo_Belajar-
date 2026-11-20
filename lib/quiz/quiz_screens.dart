import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'quiz_generator.dart';
import 'quiz_models.dart';

const _green = Color(0xFF2E7D32);
const _greenBg = Color(0xFFE8F5E9);
const _red = Color(0xFFC62828);
const _redBg = Color(0xFFFFEBEE);

/// ===================== LAYAR PENGATURAN KUIS =====================
class QuizSetupScreen extends StatefulWidget {
  final String judul;
  final String materi;
  const QuizSetupScreen({super.key, required this.judul, required this.materi});

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  double _jumlah = 50;
  int _mode = 1; // 0 = pilihan ganda, 1 = campuran, 2 = essai
  bool _loading = false;
  int _done = 0;

  double get _persenMcq {
    if (_mode == 0) return 1.0;
    if (_mode == 2) return 0.0;
    return 0.7;
  }

  Future<void> _mulai() async {
    if (widget.materi.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Materi masih kosong.')),
      );
      return;
    }
    setState(() {
      _loading = true;
      _done = 0;
    });
    try {
      final soal = await QuizGenerator.generate(
        judul: widget.judul,
        materi: widget.materi,
        jumlah: _jumlah.round(),
        persenPilihanGanda: _persenMcq,
        onProgress: (d, t) {
          if (mounted) setState(() => _done = d);
        },
      );
      if (!mounted) return;
      if (soal.isEmpty) throw Exception('Soal kosong');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => QuizPlayScreen(questions: soal)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat soal: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = _jumlah.round();
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Kuis')),
      body: SafeArea(
        child: _loading
            ? Center(
                // (BARU) kartu putih agar teks terbaca di atas gradasi
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 90,
                          height: 90,
                          child: CircularProgressIndicator(
                            value: total == 0
                                ? null
                                : (_done / total).clamp(0.0, 1.0),
                            strokeWidth: 8,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('Membuat soal $_done / $total',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Mohon tunggu, jangan tutup aplikasi.',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              )
            : Column(
                children: [
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
                          Text(widget.judul,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 24),
                          Text('Jumlah soal: $total',
                              style: Theme.of(context).textTheme.titleMedium),
                          Slider(
                            value: _jumlah,
                            min: 5,
                            max: 100,
                            divisions: 19,
                            label: '$total',
                            onChanged: (v) => setState(() => _jumlah = v),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [10, 25, 50, 75, 100]
                                .map((n) => ActionChip(
                                      label: Text('$n'),
                                      onPressed: () => setState(
                                          () => _jumlah = n.toDouble()),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 24),
                          Text('Jenis soal',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          SegmentedButton<int>(
                            showSelectedIcon: false,
                            segments: <ButtonSegment<int>>[
                              ButtonSegment<int>(
                                  value: 0, label: Text('Pilgan')),
                              ButtonSegment<int>(
                                  value: 1, label: Text('Campuran')),
                              ButtonSegment<int>(
                                  value: 2, label: Text('Essai')),
                            ],
                            selected: <int>{_mode},
                            onSelectionChanged: (Set<int> s) {
                              setState(() => _mode = s.first);
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Campuran = sekitar 70% pilihan ganda dan 30% essai. '
                            'Pilihan ganda memuat pengecoh yang tidak hanya dari isi materi.',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _mulai,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Buat & Mulai Kuis'),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// ===================== LAYAR MENGERJAKAN KUIS =====================
class QuizPlayScreen extends StatefulWidget {
  final List<QuizQuestion> questions;
  const QuizPlayScreen({super.key, required this.questions});

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  int _i = 0;
  int _score = 0;
  int? _picked;
  bool _answered = false;
  bool _checking = false;
  bool _essayCorrect = false;
  String _essayFeedback = '';
  final TextEditingController _ctrl = TextEditingController();

  QuizQuestion get _q => widget.questions[_i];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _pilih(int idx) {
    if (_answered) return;
    HapticFeedback.lightImpact();
    final benar = idx == _q.correctIndex;
    setState(() {
      _picked = idx;
      _answered = true;
      if (benar) _score++;
    });
  }

  Future<void> _periksaEssai() async {
    final jawab = _ctrl.text.trim();
    if (jawab.isEmpty || _checking) return;
    FocusScope.of(context).unfocus();
    setState(() => _checking = true);
    final r = await QuizGenerator.gradeEssay(q: _q, userAnswer: jawab);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _checking = false;
      _answered = true;
      _essayCorrect = r.correct;
      _essayFeedback = r.feedback;
      if (r.correct) _score++;
    });
  }

  void _lanjut() {
    if (_i + 1 >= widget.questions.length) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
            score: _score,
            total: widget.questions.length,
            questions: widget.questions,
          ),
        ),
      );
      return;
    }
    setState(() {
      _i++;
      _picked = null;
      _answered = false;
      _essayCorrect = false;
      _essayFeedback = '';
      _ctrl.clear();
    });
  }

  Future<bool> _konfirmasiKeluar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Keluar dari kuis?'),
        content: const Text('Progress kuis ini akan hilang.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Lanjut kuis')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Keluar')),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.questions.length;
    final q = _q;
    final isMcq = q.type == QuizType.pilihanGanda;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _konfirmasiKeluar();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Soal ${_i + 1} dari $total'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final ok = await _konfirmasiKeluar();
              if (ok && mounted) Navigator.pop(context);
            },
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: LinearProgressIndicator(value: (_i + 1) / total),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        backgroundColor: Colors.white, // (BARU) agar terbaca
                        avatar: Icon(
                            isMcq ? Icons.checklist : Icons.edit_note,
                            size: 18),
                        label: Text(isMcq ? 'Pilihan Ganda' : 'Essai'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(q.question,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isMcq) ..._buildOptions(q) else ..._buildEssay(),
                    if (_answered) ...[
                      const SizedBox(height: 12),
                      _buildFeedback(q, isMcq),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: _bottomButton(isMcq, total),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomButton(bool isMcq, int total) {
    if (_answered) {
      return FilledButton(
        onPressed: _lanjut,
        child: Text(_i + 1 >= total ? 'Lihat Hasil' : 'Lanjut'),
      );
    }
    if (!isMcq) {
      return FilledButton(
        onPressed: _checking ? null : _periksaEssai,
        child: _checking
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 3))
            : const Text('Periksa Jawaban'),
      );
    }
    return const FilledButton(
        onPressed: null, child: Text('Pilih salah satu jawaban'));
  }

  List<Widget> _buildOptions(QuizQuestion q) {
    return List<Widget>.generate(q.options.length, (idx) {
      final isCorrect = idx == q.correctIndex;
      final isPicked = idx == _picked;

      Color bg = Theme.of(context).colorScheme.surface;
      Color border = Theme.of(context).colorScheme.outlineVariant;
      Color fg = Theme.of(context).colorScheme.onSurface;
      IconData? trailing;

      if (_answered) {
        if (isCorrect) {
          bg = _greenBg;
          border = _green;
          fg = _green;
          trailing = Icons.check_circle;
        } else if (isPicked) {
          bg = _redBg;
          border = _red;
          fg = _red;
          trailing = Icons.cancel;
        }
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: border,
                width: _answered && (isCorrect || isPicked) ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _pilih(idx),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: fg.withValues(alpha: 0.12),
                    child: Text(String.fromCharCode(65 + idx),
                        style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(q.options[idx],
                        style: TextStyle(color: fg, fontSize: 15)),
                  ),
                  if (trailing != null) Icon(trailing, color: fg),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _buildEssay() {
    return [
      TextField(
        controller: _ctrl,
        enabled: !_answered && !_checking,
        minLines: 4,
        maxLines: 8,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'Tulis jawabanmu di sini...',
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ];
  }

  Widget _buildFeedback(QuizQuestion q, bool isMcq) {
    final benar = isMcq ? _picked == q.correctIndex : _essayCorrect;
    final color = benar ? _green : _red;
    final bg = benar ? _greenBg : _redBg;

    final penjelasan = isMcq
        ? q.explanation
        : [
            if (_essayFeedback.isNotEmpty) _essayFeedback,
            if (q.explanation.isNotEmpty) q.explanation,
          ].join('\n\n');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 450),
                curve: Curves.elasticOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Icon(
                  benar ? Icons.check_circle : Icons.cancel,
                  color: color,
                  size: isMcq ? 28 : 44,
                ),
              ),
              const SizedBox(width: 10),
              Text(benar ? 'Benar!' : 'Salah',
                  style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          if (isMcq && !benar) ...[
            const SizedBox(height: 10),
            Text('Jawaban benar: ${q.options[q.correctIndex]}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          if (!isMcq) ...[
            const SizedBox(height: 10),
            Text('Kunci jawaban: ${q.answerKey}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          if (penjelasan.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Penjelasan',
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(penjelasan, style: const TextStyle(height: 1.4)),
          ],
        ],
      ),
    );
  }
}

/// ===================== LAYAR HASIL =====================
class QuizResultScreen extends StatelessWidget {
  final int score;
  final int total;
  final List<QuizQuestion> questions;
  const QuizResultScreen({
    super.key,
    required this.score,
    required this.total,
    required this.questions,
  });

  @override
  Widget build(BuildContext context) {
    final persen = total == 0 ? 0 : (score / total * 100).round();
    final bagus = persen >= 70;
    final color = bagus ? _green : _red;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Hasil Kuis'), automaticallyImplyLeading: false),
      body: SafeArea(
        // (BARU) kartu putih agar teks terbaca di atas gradasi
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: persen / 100,
                        strokeWidth: 12,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.15),
                      ),
                      Center(
                        child: Text('$persen%',
                            style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: color)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('$score benar dari $total soal',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(bagus
                    ? 'Mantap, pertahankan!'
                    : 'Ayo belajar lagi, kamu pasti bisa!'),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Selesai'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}