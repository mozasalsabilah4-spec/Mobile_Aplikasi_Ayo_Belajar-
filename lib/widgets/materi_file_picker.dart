import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';

class MateriFilePicker extends StatefulWidget {
  /// Dipanggil saat teks dari file berhasil diambil.
  final void Function(String teks) onTeksDiambil;

  const MateriFilePicker({super.key, required this.onTeksDiambil});

  @override
  State<MateriFilePicker> createState() => _MateriFilePickerState();
}

class _MateriFilePickerState extends State<MateriFilePicker> {
  bool _loading = false;
  String? _namaFile;

  Future<void> _pilihFile() async {
    final hasil = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'pdf'],
    );
    if (hasil.isEmpty) return;

    final file = hasil.first;
    setState(() {
      _loading = true;
      _namaFile = file.name;
    });

    try {
      final bytes = await file.readAsBytes();
      String teks;

      if ((file.extension ?? '').toLowerCase() == 'pdf') {
        final model = FirebaseAI.googleAI()
            .generativeModel(model: 'gemini-3.8-flash');
        final respon = await model.generateContent([
          Content.multi([
            TextPart('Ekstrak isi materi dari dokumen ini menjadi teks '
                'yang rapi, tanpa komentar tambahan.'),
            InlineDataPart('application/pdf', bytes),
          ]),
        ]);
        teks = respon.text ?? '';
      } else {
        teks = utf8.decode(bytes, allowMalformed: true);
      }

      if (teks.trim().isEmpty) {
        throw Exception('Isi file kosong atau tidak terbaca');
      }
      widget.onTeksDiambil(teks);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membaca file: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _loading ? null : _pilihFile,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file),
          label: Text(_loading ? 'Membaca file...' : 'Unggah file materi'),
        ),
        if (_namaFile != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_namaFile!,
                style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}