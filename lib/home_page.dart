import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'deck_page.dart';
import 'dialogs.dart';
import 'firestore_service.dart';
import 'models.dart';
import 'kartu_ai_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _addDeck(BuildContext context, FirestoreService service) async {
    final v = await showFormDialog(
      context,
      title: 'Deck baru',
      labels: ['Nama deck (mis. Kosakata Inggris)'],
      confirmText: 'Buat',
    );
    if (v != null) await service.addDeck(v[0]);
  }

  Future<void> _rename(
      BuildContext context, FirestoreService service, Deck deck) async {
    final v = await showFormDialog(
      context,
      title: 'Ubah nama deck',
      labels: ['Nama deck'],
      initial: [deck.title],
    );
    if (v != null) await service.renameDeck(deck.id, v[0]);
  }

  Future<void> _delete(
      BuildContext context, FirestoreService service, Deck deck) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus deck?',
      message: 'Deck "${deck.title}" beserta semua kartunya akan dihapus.',
    );
    if (ok) await service.deleteDeck(deck.id);
  }

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (user?.email ?? 'Pelajar');
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDeck(context, service),
        icon: const Icon(Icons.add),
        label: const Text('Deck baru'),
      ),
      body: StreamBuilder<List<Deck>>(
        stream: service.decks(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat data.\n'
                  'Pastikan Firestore sudah diaktifkan dan rules sudah diatur.\n\n'
                  '${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final decks = snap.data ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Text('Halo, $name!',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                decks.isEmpty
                    ? 'Mulai dengan membuat deck pertamamu.'
                    : 'Pilih deck untuk belajar atau mengelola kartu.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (decks.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 64),
                  child: Column(
                    children: [
                      Icon(Icons.style_outlined,
                          size: 72, color: scheme.outline),
                      const SizedBox(height: 12),
                      const Text('Belum ada deck'),
                    ],
                  ),
                ),
              for (final deck in decks)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(Icons.style, color: scheme.onPrimaryContainer),
                    ),
                    title: Text(deck.title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${deck.cardCount} kartu'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'rename') _rename(context, service, deck);
                        if (v == 'delete') _delete(context, service, deck);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Ubah nama')),
                        PopupMenuItem(value: 'delete', child: Text('Hapus')),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DeckPage(deck: deck)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}