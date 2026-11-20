import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_ai/firebase_ai.dart';

import 'kartu_ai_page.dart' show namaModelAi;

const int _batasMb = 10;

const Map<String, String> _mimeGambar = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'heif': 'image/heif',
};

const List<String> _formatLama = ['doc', 'ppt', 'xls', 'rtf', 'odt'];

/// Membaca isi file apa pun yang didukung menjadi teks.
Future<String> bacaTeksMateri(PlatformFile file) async {
  final ext = (file.extension ?? '').toLowerCase();
  final bytes = await file.readAsBytes();

  if (bytes.length > _batasMb * 1024 * 1024) {
    throw Exception('Ukuran file maksimal $_batasMb MB');
  }

  String teks;
  if (ext == 'pdf') {
    teks = await _dariGemini(bytes, 'application/pdf');
  } else if (_mimeGambar.containsKey(ext)) {
    teks = await _dariGemini(bytes, _mimeGambar[ext]!);
  } else if (ext == 'docx') {
    teks = _dariDocx(bytes);
  } else if (ext == 'pptx') {
    teks = _dariPptx(bytes);
  } else if (ext == 'xlsx') {
    teks = _dariXlsx(bytes);
  } else if (_formatLama.contains(ext)) {
    throw Exception('Format .$ext lama belum didukung. '
        'Simpan ulang sebagai .docx, .pptx, .xlsx, atau PDF');
  } else {
    // Format lain dianggap teks biasa, tolak kalau ternyata biner
    final cek = bytes.length > 2000 ? bytes.sublist(0, 2000) : bytes;
    if (cek.contains(0)) {
      throw Exception('Format file ini belum didukung');
    }
    teks = utf8.decode(bytes, allowMalformed: true);
  }

  if (teks.trim().isEmpty) {
    throw Exception('Isi file kosong atau tidak terbaca');
  }
  return teks.trim();
}

// PDF dan gambar dikirim ke Gemini
Future<String> _dariGemini(Uint8List bytes, String mime) async {
  final model = FirebaseAI.googleAI().generativeModel(model: namaModelAi);
  final respon = await model.generateContent([
    Content.multi([
      TextPart('Ubah isi materi pada file ini menjadi daftar poin. '
          'Satu poin per baris dengan format: istilah = penjelasan singkat. '
          'Tanpa nomor, tanpa komentar tambahan.'),
      InlineDataPart(mime, bytes),
    ]),
  ]);
  return respon.text ?? '';
}

// DOCX, PPTX, dan XLSX adalah arsip zip berisi XML
Archive _buka(Uint8List bytes) {
  try {
    return ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw Exception('File tidak valid atau terkunci password');
  }
}

String _xmlKeTeks(String xml) {
  return xml
      .replaceAll('</w:p>', '\n')
      .replaceAll('</a:p>', '\n')
      .replaceAll('</si>', '\n')
      .replaceAll('<w:br/>', '\n')
      .replaceAll('<w:tab/>', ' ')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}

String _isi(ArchiveFile f) =>
    utf8.decode(f.content as List<int>, allowMalformed: true);

String _dariDocx(Uint8List bytes) {
  final berkas = _buka(bytes).findFile('word/document.xml');
  if (berkas == null) throw Exception('File Word tidak valid');
  return _xmlKeTeks(_isi(berkas));
}

String _dariPptx(Uint8List bytes) {
  final slide = <int, ArchiveFile>{};
  final pola = RegExp(r'^ppt/slides/slide(\d+)\.xml$');
  for (final f in _buka(bytes).files) {
    final m = pola.firstMatch(f.name);
    if (m != null) slide[int.parse(m.group(1)!)] = f;
  }
  if (slide.isEmpty) throw Exception('File PowerPoint tidak valid');
  final urutan = slide.keys.toList()..sort();
  return urutan.map((n) => _xmlKeTeks(_isi(slide[n]!))).join('\n');
}

String _dariXlsx(Uint8List bytes) {
  final berkas = _buka(bytes).findFile('xl/sharedStrings.xml');
  if (berkas == null) throw Exception('File Excel tidak berisi teks');
  return _xmlKeTeks(_isi(berkas));
}