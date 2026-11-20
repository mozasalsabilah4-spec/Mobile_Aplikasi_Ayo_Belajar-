import 'package:flutter/material.dart';
import '../auth/kartu_auth.dart';

/// Layar daftar dengan tampilan yang sama seperti register_screen.dart,
/// tetapi akunnya benar-benar disimpan ke Firebase Auth. Setelah daftar,
/// pengguna kembali ke layar login dan harus masuk dengan email dan
/// sandi yang sama.
class RegisterAuthScreen extends StatefulWidget {
  const RegisterAuthScreen({super.key});

  @override
  State<RegisterAuthScreen> createState() => _RegisterAuthScreenState();
}

class _RegisterAuthScreenState extends State<RegisterAuthScreen> {
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _sandiController = TextEditingController();
  final _konfirmasiController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _sandiController.dispose();
    _konfirmasiController.dispose();
    super.dispose();
  }

  void _pesan(String t) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _daftar() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    if (_sandiController.text != _konfirmasiController.text) {
      _pesan('Konfirmasi kata sandi tidak sama.');
      return;
    }

    setState(() => _loading = true);
    try {
      await KartuAuth.daftar(
        nama: _namaController.text,
        email: _emailController.text,
        sandi: _sandiController.text,
      );
      if (!mounted) return;
      _pesan('Akun berhasil dibuat. Silakan masuk dengan email dan sandi tadi.');
      Navigator.pop(context);
    } on KartuAuthException catch (e) {
      if (!mounted) return;
      _pesan(e.pesan);
    } catch (e) {
      if (!mounted) return;
      _pesan('Gagal mendaftar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _dekor(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Buat Akun Baru',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3436))),
            const SizedBox(height: 8),
            const Text('Mulai hafalan mata kuliahmu sekarang!',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            TextField(
              controller: _namaController,
              textCapitalization: TextCapitalization.words,
              decoration: _dekor('Nama Lengkap', Icons.person_outline),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: _dekor('Email', Icons.email_outlined),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _sandiController,
              obscureText: true,
              decoration: _dekor('Kata Sandi (min. 6 karakter)', Icons.lock_outline),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _konfirmasiController,
              obscureText: true,
              onSubmitted: (_) => _daftar(),
              decoration: _dekor('Ulangi Kata Sandi', Icons.lock_reset),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loading ? null : _daftar,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Daftar Akun',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}