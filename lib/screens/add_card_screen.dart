import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/flashcard_model.dart';
import '../baca_file_materi.dart';
import '../quiz/quiz_groq.dart'; // (BARU) kuis AI gratis (Groq) dari materi

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _courseController = TextEditingController();
  final _materialController = TextEditingController();
  String? _uploadedFileName;

  // Fungsi untuk memilih dan membaca file dari HP/Laptop
  // Mendukung: txt, csv, md, docx, pptx, xlsx, pdf, dan gambar
  Future<void> _pickFileAndRead() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);

      if (files.isNotEmpty) {
        final file = files.first;
        setState(() => _uploadedFileName = 'Membaca ${file.name}...');

        final fileContent = await bacaTeksMateri(file);

        if (!mounted) return;
        setState(() {
          _uploadedFileName = file.name;
          _materialController.text = fileContent;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhasil memuat file: $_uploadedFileName')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadedFileName = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membaca file: $e')),
      );
    }
  }

  void _saveGeneratedQuiz() {
    String courseName = _courseController.text.trim();
    String rawMaterial = _materialController.text.trim();

    if (courseName.isEmpty || rawMaterial.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nama mata kuliah dan materi (atau file) wajib diisi!')),
      );
      return;
    }

    List<String> lines = rawMaterial.split('\n');

    Course? targetCourse;
    for (var c in AppData.courses) {
      if (c.title.toLowerCase() == courseName.toLowerCase()) {
        targetCourse = c;
        break;
      }
    }

    if (targetCourse == null) {
      targetCourse = Course(
        id: DateTime.now().toString(),
        title: courseName,
        cards: [],
      );
      AppData.courses.add(targetCourse);
    }

    int addedCount = 0;
    for (var line in lines) {
      if (line.trim().isEmpty) continue;

      String question = line.trim();
      String answer = "Penjelasan materi terkait";

      if (line.contains('=')) {
        var parts = line.split('=');
        question = parts[0].trim();
        answer = parts.length > 1 ? parts[1].trim() : '';
      } else if (line.contains(':')) {
        var parts = line.split(':');
        question = parts[0].trim();
        answer = parts.length > 1 ? parts[1].trim() : '';
      }

      targetCourse.cards.add(
        Flashcard(
          id: DateTime.now().toString() + addedCount.toString(),
          question: question,
          answer: answer,
        ),
      );
      addedCount++;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('$addedCount kartu berhasil dibuat untuk "$courseName"!')),
    );

    _materialController.clear();
    setState(() {
      _uploadedFileName = null;
    });
  }

  InputDecoration _fieldStyle(String hint) {
    const purple = Color(0xFF6A3FC4);
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black54),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: purple),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: purple),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: purple, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Buat Kartu dari File/Materi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nama Mata Kuliah',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white)),
            const SizedBox(height: 8),
            TextField(
              controller: _courseController,
              decoration: _fieldStyle('Ketik bebas nama mata kuliah'),
            ),
            const SizedBox(height: 20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text(
                    'Masukkan Materi atau Upload File',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF5A1FC8),
                    elevation: 1,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _pickFileAndRead,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Pilih File'),
                ),
              ],
            ),
            if (_uploadedFileName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text('File terpilih: $_uploadedFileName',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 8),

            TextField(
              controller: _materialController,
              maxLines: 6,
              decoration: _fieldStyle(
                  'Atau ketik materi di sini...\nContoh per baris:\nApa itu API? = Antarmuka Pemrograman\nFlutter = Framework UI Google'),
            ),
            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A00B8), Color(0xFF9A00C8)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4)),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _saveGeneratedQuiz,
                child: const Text('Buat & Simpan Kartu',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),

            // (BARU) Kuis AI dari materi, dipindahkan ke halaman Buat Kartu
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF5A1FC8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => bukaKuisGratisDariMateri(
                  context,
                  mataKuliah: _courseController.text,
                  materi: _materialController.text,
                ),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Kuis Otomatis (AI)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}