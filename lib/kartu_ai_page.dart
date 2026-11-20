// ============================================================
// lib/kartu_ai_page.dart
// Fitur "Buat kartu dengan AI" untuk halaman Buat Kartu.
// Pengguna menempel teks materi atau mengunggah file
// (PDF, Word, PowerPoint, Excel, gambar, atau teks).
// AI (Gemini lewat Firebase AI Logic) langsung membuat kartu belajar,
// lalu halaman ini mengembalikan semua kartu ke halaman pemanggil
// untuk disimpan dengan fungsi simpan yang sudah ada di aplikasimu.
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';

import 'baca_file_materi.dart';

// Nama model Gemini. Jika muncul error "model not found" atau
// "not supported", ganti dengan nama model terbaru dari dokumentasi
// Firebase AI Logic (misalnya 'gemini-3.8-flash').
const String namaModelAi = 'gemini-3.8-flash';

const int batasUkuranFileMb = 10;
const int batasHurufTeks = 30000;

// ------------------------------------------------------------
// Bagian 1: Model hasil dan layanan AI
// ------------------------------------------------------------
class KartuAi {
  String pertanyaan;
  String jawaban;
  bool dipilih;
  KartuAi(this.pertanyaan, this.jawaban, {this.dipilih = true});
}

class KartuAiService {
  static String _prompt(int jumlah) => '''
Kamu adalah asisten belajar untuk mahasiswa.
Buat $jumlah kartu belajar (flashcard) berbahasa Indonesia dari materi yang diberikan.
Aturan:
- Setiap kartu berisi satu pertanyaan singkat dan satu jawaban ringkas (maksimal 2 kalimat).
- Isi kartu hanya boleh berdasarkan materi, jangan menambah fakta di luar materi.
- Variasikan jenis pertanyaan (definisi, fungsi, perbedaan, contoh).
- Balas HANYA dengan JSON array, tanpa teks lain, dengan format:
[{"pertanyaan": "...", "jawaban": "..."}]
''';

  // Materi berupa teks (ketikan, tempelan, atau hasil baca file)
  static Future<List<KartuAi>> dariTeks(String teks, {int jumlah = 8}) {
    final materi =
        teks.length > batasHurufTeks ? teks.substring(0, batasHurufTeks) : teks;
    return _minta([TextPart('${_prompt(jumlah)}\nMATERI:\n$materi')]);
  }

  // Materi berupa file PDF (dikirim langsung ke Gemini)
  static Future<List<KartuAi>> dariPdf(Uint8List bytes, {int jumlah = 8}) {
    return _minta([
      TextPart(_prompt(jumlah)),
      InlineDataPart('application/pdf', bytes),
    ]);
  }

  static Future<List<KartuAi>> _minta(List<Part> bagian) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: namaModelAi,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
    final respons = await model.generateContent([Content.multi(bagian)]);
    return _urai(respons.text);
  }

  // Mengubah jawaban JSON dari AI menjadi daftar kartu
  static List<KartuAi> _urai(String? teks) {
    if (teks == null || teks.trim().isEmpty) {
      throw Exception('AI tidak mengembalikan jawaban. Coba lagi.');
    }
    final awal = teks.indexOf('[');
    final akhir = teks.lastIndexOf(']');
    if (awal < 0 || akhir <= awal) {
      throw Exception('Format jawaban AI tidak dikenali. Coba lagi.');
    }
    final data = jsonDecode(teks.substring(awal, akhir + 1));
    if (data is! List) {
      throw Exception('Format jawaban AI tidak dikenali. Coba lagi.');
    }
    final hasil = <KartuAi>[];
    for (final item in data) {
      if (item is Map) {
        final p = item['pertanyaan']?.toString().trim() ?? '';
        final j = item['jawaban']?.toString().trim() ?? '';
        if (p.isNotEmpty && j.isNotEmpty) hasil.add(KartuAi(p, j));
      }
    }
    if (hasil.isEmpty) {
      throw Exception('AI tidak menghasilkan kartu. Coba materi yang lebih jelas.');
    }
    return hasil;
  }
}

// ------------------------------------------------------------
// Bagian 2: Halaman "Buat kartu dengan AI"
// ------------------------------------------------------------
enum _Sumber { teks, file }

class KartuAiPage extends StatefulWidget {
  const KartuAiPage({super.key});
  @override
  State<KartuAiPage> createState() => _KartuAiPageState();
}

class _KartuAiPageState extends State<KartuAiPage> {
  final _teks = TextEditingController();
  _Sumber _sumber = _Sumber.teks;
  String? _namaFile;
  Uint8List? _bytesFile;
  bool _filePdf = false;
  double _jumlah = 8;
  bool _memproses = false;
  String? _error;

  @override
  void dispose() {
    _teks.dispose();
    super.dispose();
  }

  String _bersihkan(Object e) => e.toString().replaceFirst('Exception: ', '');

  // Memilih file, lalu langsung membuat kartu begitu file terbaca
  Future<void> _pilihFile() async {
    final hasil = await FilePicker.pickFiles(type: FileType.any);
    if (hasil.isEmpty) return;

    final f = hasil.first;
    var siap = false;
    try {
      final ext = (f.extension ?? '').toLowerCase();
      final bytes = await f.readAsBytes();
      if (bytes.length > batasUkuranFileMb * 1024 * 1024) {
        setState(() => _error = 'Ukuran file maksimal $batasUkuranFileMb MB.');
        return;
      }
      if (ext == 'pdf') {
        // PDF dikirim langsung ke Gemini
        setState(() {
          _namaFile = f.name;
          _bytesFile = bytes;
          _filePdf = true;
          _error = null;
        });
      } else {
        // Format lain diubah dulu menjadi teks
        setState(() => _memproses = true);
        final teks = await bacaTeksMateri(f);
        if (!mounted) return;
        setState(() {
          _namaFile = f.name;
          _bytesFile = Uint8List.fromList(utf8.encode(teks));
          _filePdf = false;
          _error = null;
        });
      }
      siap = true;
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _bersihkan(e));
    } finally {
      if (mounted) setState(() => _memproses = false);
    }

    if (siap && mounted) await _buat();
  }

  // Membuat kartu dengan AI, lalu langsung mengembalikan semuanya
  Future<void> _buat() async {
    setState(() => _error = null);

    if (_sumber == _Sumber.teks) {
      if (_teks.text.trim().length < 30) {
        setState(() => _error = 'Tulis atau tempel materi minimal beberapa kalimat.');
        return;
      }
    } else if (_bytesFile == null) {
      setState(() => _error = 'Pilih file terlebih dahulu.');
      return;
    }

    setState(() => _memproses = true);
    try {
      final jumlah = _jumlah.round();
      final List<KartuAi> kartu;
      if (_sumber == _Sumber.teks) {
        kartu = await KartuAiService.dariTeks(_teks.text.trim(), jumlah: jumlah);
      } else if (_filePdf) {
        kartu = await KartuAiService.dariPdf(_bytesFile!, jumlah: jumlah);
      } else {
        final isi = utf8.decode(_bytesFile!, allowMalformed: true);
        kartu = await KartuAiService.dariTeks(isi, jumlah: jumlah);
      }
      if (!mounted) return;
      // Semua kartu langsung dikembalikan untuk disimpan
      Navigator.pop(context, kartu);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal membuat kartu: ${_bersihkan(e)}';
                _memproses = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Kartu dengan AI')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_Sumber>(
            segments: const [
              ButtonSegment(value: _Sumber.teks, icon: Icon(Icons.notes), label: Text('Tempel teks')),
              ButtonSegment(value: _Sumber.file, icon: Icon(Icons.upload_file), label: Text('Unggah file')),
            ],
            selected: {_sumber},
            onSelectionChanged: _memproses
                ? null
                : (s) => setState(() {
                      _sumber = s.first;
                      _error = null;
                    }),
          ),
          const SizedBox(height: 16),
          if (_sumber == _Sumber.teks)
            TextField(
              controller: _teks,
              enabled: !_memproses,
              minLines: 6,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: 'Materi',
                hintText: 'Tempel atau ketik materi di sini',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            )
          else ...[
            OutlinedButton.icon(
              onPressed: _memproses ? null : _pilihFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_namaFile == null ? 'Pilih file' : 'Ganti file'),
            ),
            const SizedBox(height: 8),
            if (_namaFile != null)
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_namaFile!, overflow: TextOverflow.ellipsis)),
                ],
              ),
            const SizedBox(height: 4),
            const Text(
              'Format: PDF, Word (.docx), PowerPoint (.pptx), Excel (.xlsx), '
              'gambar, atau teks. Maksimal $batasUkuranFileMb MB. '
              'Kartu langsung dibuat setelah file dipilih.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 16),
          Text('Jumlah kartu: ${_jumlah.round()}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: _jumlah,
            min: 3,
            max: 15,
            divisions: 12,
            label: _jumlah.round().toString(),
            onChanged: _memproses ? null : (v) => setState(() => _jumlah = v),
          ),
          if (_sumber == _Sumber.teks) ...[
            const SizedBox(height: 4),
            FilledButton.icon(
              onPressed: _memproses ? null : _buat,
              icon: _memproses
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_memproses ? 'AI sedang membuat kartu...' : 'Buat kartu dengan AI'),
            ),
          ] else if (_memproses) ...[
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('AI sedang membuat kartu...'),
              ],
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            'Materi dikirim ke layanan Gemini (Google) untuk diproses. '
            'Jangan kirim data pribadi atau rahasia.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 6),
                  const Text(
                    'Pastikan internet aktif dan Firebase AI Logic sudah diaktifkan '
                    'di Firebase Console.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}