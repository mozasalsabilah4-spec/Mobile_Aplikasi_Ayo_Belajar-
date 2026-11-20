import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Daftar akun baru. Mengembalikan null jika sukses, atau pesan error.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(name.trim());
      await cred.user?.sendEmailVerification(); // kirim email verifikasi
      await cred.user?.reload();
      return null;
    } on FirebaseAuthException catch (e) {
      return _pesanError(e.code);
    } catch (_) {
      return 'Terjadi kesalahan. Coba lagi.';
    }
  }

  /// Masuk dengan email dan password. Null = sukses.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _pesanError(e.code);
    } catch (_) {
      return 'Terjadi kesalahan. Coba lagi.';
    }
  }

  /// Kirim link reset password ke email. Null = sukses.
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _pesanError(e.code);
    }
  }

  Future<void> logout() => _auth.signOut();

  String _pesanError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Silakan login.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'weak-password':
        return 'Password terlalu lemah (minimal 6 karakter).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau password salah.';
      case 'user-disabled':
        return 'Akun ini dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet.';
      default:
        return 'Gagal ($code).';
    }
  }
}