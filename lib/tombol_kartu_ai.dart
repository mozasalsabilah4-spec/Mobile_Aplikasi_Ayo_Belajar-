// ============================================================
// lib/tombol_kartu_ai.dart
// Tombol "Buat kartu dengan AI". File BARU: tidak mengubah file lama.
// Cukup tempel widget ini di halaman deck, lalu isi onSimpan dengan
// pemanggilan simpan-kartu yang SUDAH ada di aplikasimu.
// ============================================================

import 'package:flutter/material.dart';

import 'kartu_ai_page.dart';

class TombolKartuAi extends StatelessWidget {
  /// Dipanggil satu kali untuk setiap kartu yang dipilih pengguna.
  /// Isi dengan fungsi simpan kartu milikmu, misalnya:
  /// (pertanyaan, jawaban) => service.addCard(deck.id, pertanyaan, jawaban)
  final Future<void> Function(String pertanyaan, String jawaban) onSimpan;

  /// true = tampil sebagai ikon saja (cocok untuk AppBar actions)
  final bool ikonSaja;

  const TombolKartuAi({
    super.key,
    required this.onSimpan,
    this.ikonSaja = false,
  });

  Future<void> _buka(BuildContext context) async {
    final hasil = await Navigator.push<List<KartuAi>>(
      context,
      MaterialPageRoute(builder: (_) => const KartuAiPage()),
    );
    if (hasil == null || hasil.isEmpty) return;

    var berhasil = 0;
    try {
      for (final k in hasil) {
        await onSimpan(k.pertanyaan, k.jawaban);
        berhasil++;
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan setelah $berhasil kartu: $e')),
      );
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$berhasil kartu disimpan')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ikonSaja) {
      return IconButton(
        tooltip: 'Buat kartu dengan AI',
        icon: const Icon(Icons.auto_awesome),
        onPressed: () => _buka(context),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => _buka(context),
      icon: const Icon(Icons.auto_awesome),
      label: const Text('Buat kartu dengan AI'),
    );
  }
}