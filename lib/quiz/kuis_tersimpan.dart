import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/flashcard_model.dart';
import 'quiz_models.dart';

/// Satu kuis yang sudah dibuat AI dan disimpan di sebuah mata kuliah.
class KuisTersimpan {
  final String id;
  final String mataKuliah;
  final DateTime dibuat;
  final List<QuizQuestion> soal;

  const KuisTersimpan({
    required this.id,
    required this.mataKuliah,
    required this.dibuat,
    required this.soal,
  });

  int get jumlah => soal.length;
}

/// Penyimpanan kuis per mata kuliah.
/// Kuis disimpan PERMANEN di HP (tetap ada walau aplikasi ditutup),
/// dan dipisah per akun yang login.
class KuisStore {
  KuisStore._();

  static final List<KuisTersimpan> _daftar = [];

  /// Naik setiap ada perubahan, supaya beranda otomatis menyegarkan tampilan.
  static final ValueNotifier<int> versi = ValueNotifier<int>(0);

  /// Akun yang kuisnya sudah dimuat dari HP (supaya tidak dimuat berulang-ulang).
  static String? _sudahDimuatUntuk;

  static String _kunci(String s) => s.trim().toLowerCase();

  /// Kunci penyimpanan di HP, berbeda untuk tiap akun.
  static String get _kunciSimpan {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'tamu';
    return 'kuis_tersimpan_$uid';
  }

  /// Semua kuis milik satu mata kuliah, yang terbaru di paling atas.
  static List<KuisTersimpan> untuk(String mataKuliah) {
    return _daftar
        .where((k) => _kunci(k.mataKuliah) == _kunci(mataKuliah))
        .toList()
        .reversed
        .toList();
  }

  /// Pastikan mata kuliah ada di beranda; jika belum, dibuat otomatis.
  static void _pastikanMataKuliah(String nama) {
    final sudahAda =
        AppData.courses.any((c) => _kunci(c.title) == _kunci(nama));
    if (!sudahAda) {
      AppData.courses.add(
        Course(
          id: DateTime.now().toString(),
          title: nama,
          cards: [],
        ),
      );
    }
  }

  /// Muat kuis dari HP untuk akun yang sedang login.
  /// Dipanggil saat beranda dibuka.
  static Future<void> muat() async {
    final kunciAkun = _kunciSimpan;
    if (_sudahDimuatUntuk == kunciAkun) {
      versi.value++;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final mentah = prefs.getString(kunciAkun);

      _daftar.clear();
      if (mentah != null && mentah.isNotEmpty) {
        final list = jsonDecode(mentah) as List;
        for (final item in list) {
          try {
            final m = Map<String, dynamic>.from(item as Map);
            final soal = (m['soal'] as List)
                .map((e) =>
                    QuizQuestion.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
            final kuis = KuisTersimpan(
              id: m['id'] as String,
              mataKuliah: m['mataKuliah'] as String,
              dibuat: DateTime.parse(m['dibuat'] as String),
              soal: List<QuizQuestion>.unmodifiable(soal),
            );
            _daftar.add(kuis);
            // mata kuliahnya dimunculkan lagi di beranda
            _pastikanMataKuliah(kuis.mataKuliah);
          } catch (_) {
            // data yang rusak dilewati saja
          }
        }
      }
      _sudahDimuatUntuk = kunciAkun;
    } catch (_) {
      // jika gagal membaca penyimpanan, aplikasi tetap jalan
    }
    versi.value++;
  }

  static Map<String, dynamic> _soalKeJson(QuizQuestion q) => {
        'type': q.type == QuizType.pilihanGanda ? 'pilihan_ganda' : 'essai',
        'question': q.question,
        'options': q.options,
        'correctIndex': q.correctIndex,
        'answerKey': q.answerKey,
        'explanation': q.explanation,
      };

  static Future<void> _simpanKeHp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _daftar
          .map((k) => {
                'id': k.id,
                'mataKuliah': k.mataKuliah,
                'dibuat': k.dibuat.toIso8601String(),
                'soal': k.soal.map(_soalKeJson).toList(),
              })
          .toList();
      await prefs.setString(_kunciSimpan, jsonEncode(data));
    } catch (_) {
      // gagal menyimpan tidak boleh membuat aplikasi error
    }
  }

  /// Simpan kuis ke mata kuliah (di memori dan di HP).
  static KuisTersimpan simpan({
    required String mataKuliah,
    required List<QuizQuestion> soal,
  }) {
    final nama = mataKuliah.trim();
    _pastikanMataKuliah(nama);

    final kuis = KuisTersimpan(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      mataKuliah: nama,
      dibuat: DateTime.now(),
      soal: List<QuizQuestion>.unmodifiable(soal),
    );
    _daftar.add(kuis);
    versi.value++;
    _simpanKeHp();
    return kuis;
  }

  static void hapus(String id) {
    _daftar.removeWhere((k) => k.id == id);
    versi.value++;
    _simpanKeHp();
  }
}