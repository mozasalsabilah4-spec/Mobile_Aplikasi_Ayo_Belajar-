import 'package:flutter/material.dart';
import '../models/flashcard_model.dart';
import 'course_detail_screen.dart';
import '../auth/kartu_auth.dart'; // (BARU) untuk mengambil nama akun yang login
import '../quiz/kuis_tersimpan.dart'; // (BARU) kuis yang tersimpan per mata kuliah
import '../quiz/quiz_screens.dart'; // (BARU) QuizPlayScreen untuk memulai kuis tersimpan

// Variabel global untuk menyimpan nama pengguna yang sedang login/mendaftar
class UserSession {
  // (BARU) sebelumnya: static String userName = 'Moza';
  // Sekarang selalu mengambil nama dari akun yang sedang login.
  static String get userName => KartuAuth.namaPengguna();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // (BARU) muat kuis yang tersimpan di HP saat beranda dibuka
  @override
  void initState() {
    super.initState();
    KuisStore.muat();
  }

  // (BARU) pengganti _bukaKuis: membuka kuis yang tersimpan di mata kuliah
  void _mulaiKuis(KuisTersimpan k) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => QuizPlayScreen(questions: k.soal)),
    );
  }

  // (BARU)
  Future<void> _hapusKuis(KuisTersimpan k) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus kuis ini?'),
        content: Text('${k.jumlah} soal akan dihapus dari ${k.mataKuliah}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) KuisStore.hapus(k.id);
  }

  // (BARU)
  String _tanggal(DateTime d) {
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${dua(d.day)}/${dua(d.month)} ${dua(d.hour)}.${dua(d.minute)}';
  }

  // (BARU) daftar kuis tersimpan di bawah kartu mata kuliah
  Widget _bagianKuis(Course course) {
    final daftar = KuisStore.untuk(course.title);
    if (daftar.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kuis tersimpan',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF5A1FC8))),
          const SizedBox(height: 4),
          for (final k in daftar)
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    size: 18, color: Color(0xFF5A1FC8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${k.jumlah} soal • ${_tanggal(k.dibuat)}',
                      style: const TextStyle(color: Colors.black87)),
                ),
                TextButton(
                  onPressed: () => _mulaiKuis(k),
                  child: const Text('Mulai'),
                ),
                IconButton(
                  onPressed: () => _hapusKuis(k),
                  tooltip: 'Hapus kuis',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: Colors.black54),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Kartu Belajar',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Halo, ${UserSession.userName}!',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          const SizedBox(height: 12),

          // (BARU) Banner "Progres Hafalan" dihapus.

          // (BARU) Kartu "Kuis Otomatis" dipindahkan ke halaman Buat Kartu.
          // Kuis yang dibuat di sana tersimpan di mata kuliah (lihat di bawah).

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Mata Kuliah Anda',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              TextButton.icon(
                onPressed: () {
                  _showAddCourseDialog();
                },
                icon: const Icon(Icons.add, color: Color(0xFF2E1A6B)),
                label: const Text('Tambah',
                    style: TextStyle(
                        color: Color(0xFF2E1A6B),
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // (BARU) dibungkus ValueListenableBuilder agar kuis baru langsung muncul
          ValueListenableBuilder<int>(
            valueListenable: KuisStore.versi,
            builder: (context, _, __) {
              return AppData.courses.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'Belum ada mata kuliah.\nKetuk "+ Tambah" atau buat kartu dari file.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  : Column(
                      children: AppData.courses
                          .map((course) => Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                  children: [
                                    ListTile(
                                      title: Text(course.title,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      subtitle: Text(
                                          '[${course.totalCount}] kartu • [${course.masteredCount}] hafal'),
                                      trailing:
                                          const Icon(Icons.chevron_right),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  CourseDetailScreen(
                                                      course: course)),
                                        ).then((_) => setState(() {}));
                                      },
                                    ),
                                    // (BARU) kuis tersimpan untuk mata kuliah ini
                                    _bagianKuis(course),
                                  ],
                                ),
                              ))
                          .toList(),
                    );
            },
          ),
        ],
      ),
    );
  }

  void _showAddCourseDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ketik Nama Mata Kuliah'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Misal: Struktur Data',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7)),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    AppData.courses.add(Course(
                      id: DateTime.now().toString(),
                      title: controller.text.trim(),
                      cards: [],
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Simpan',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}