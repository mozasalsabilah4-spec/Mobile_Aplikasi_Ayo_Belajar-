import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Error yang pesannya sudah siap ditampilkan ke pengguna.
class KartuAuthException implements Exception {
  final String pesan;
  const KartuAuthException(this.pesan);
  @override
  String toString() => pesan;
}

class KartuAuth {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  /// true selama proses pendaftaran berjalan, supaya gate tidak
  /// sempat membuka beranda saat akun baru otomatis login.
  static bool sedangDaftar = false;

  /// Daftar akun baru. Email + sandi disimpan di Firebase Auth.
  /// Setelah berhasil, pengguna dikeluarkan lagi agar HARUS login
  /// memakai email dan sandi yang sama dengan saat daftar.
  static Future<void> daftar({
    required String nama,
    required String email,
    required String sandi,
  }) async {
    if (nama.trim().isEmpty) {
      throw const KartuAuthException('Nama lengkap tidak boleh kosong.');
    }
    _validasi(email, sandi);

    sedangDaftar = true;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: sandi,
      );
      await cred.user?.updateDisplayName(nama.trim());
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw KartuAuthException(_pesan(e.code));
    } finally {
      sedangDaftar = false;
    }
  }

  /// Masuk. Melempar [KartuAuthException] jika email atau sandi
  /// tidak sama dengan yang didaftarkan, sehingga tidak bisa masuk beranda.
  static Future<void> masuk({
    required String email,
    required String sandi,
  }) async {
    _validasi(email, sandi);
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: sandi,
      );
    } on FirebaseAuthException catch (e) {
      throw KartuAuthException(_pesan(e.code));
    }
  }

  static Future<void> keluar() => _auth.signOut();

  /// Nama pengguna yang sedang login. Urutan: nama saat daftar,
  /// lalu bagian depan email, lalu 'Pengguna'.
  static String namaPengguna([User? user]) {
    final u = user ?? _auth.currentUser;
    final nama = (u?.displayName ?? '').trim();
    if (nama.isNotEmpty) return nama;
    final email = u?.email ?? '';
    if (email.contains('@')) return email.split('@').first;
    return 'Pengguna';
  }

  static void _validasi(String email, String sandi) {
    final e = email.trim();
    if (e.isEmpty || sandi.isEmpty) {
      throw const KartuAuthException('Email dan sandi tidak boleh kosong.');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      throw const KartuAuthException('Format email tidak valid.');
    }
  }

  static String _pesan(String kode) {
    switch (kode) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email atau sandi salah.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-disabled':
        return 'Akun ini dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Silakan masuk.';
      case 'weak-password':
        return 'Sandi terlalu lemah (minimal 6 karakter).';
      case 'operation-not-allowed':
        return 'Login Email/Password belum diaktifkan di Firebase Console.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet.';
      default:
        return 'Terjadi kesalahan ($kode).';
    }
  }
}

/// Penjaga halaman: beranda hanya terlihat jika pengguna sudah login.
class KartuAuthGate extends StatelessWidget {
  final Widget halamanLogin;
  final Widget halamanBeranda;

  const KartuAuthGate({
    super.key,
    required this.halamanLogin,
    required this.halamanBeranda,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasData && !KartuAuth.sedangDaftar) {
          return halamanBeranda;
        }
        return halamanLogin;
      },
    );
  }
}

/// Tombol keluar siap pakai. Letakkan di AppBar (actions) halaman beranda.
class TombolKeluarKartu extends StatelessWidget {
  const TombolKeluarKartu({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Keluar',
      icon: const Icon(Icons.logout),
      onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Keluar dari akun?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Keluar'),
              ),
            ],
          ),
        );
        if (ok == true) await KartuAuth.keluar();
      },
    );
  }
}

/// Teks nama pengguna yang sedang login. Contoh:
/// TeksNamaPengguna(awalan: 'Halo, ', akhiran: '!', style: TextStyle(...))
class TeksNamaPengguna extends StatelessWidget {
  final String awalan;
  final String akhiran;
  final TextStyle? style;

  const TeksNamaPengguna({
    super.key,
    this.awalan = '',
    this.akhiran = '',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snap) {
        return Text(
          '$awalan${KartuAuth.namaPengguna(snap.data)}$akhiran',
          style: style,
        );
      },
    );
  }
}