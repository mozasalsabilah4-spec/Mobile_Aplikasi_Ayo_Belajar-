import 'package:flutter/material.dart';

import 'dialogs.dart';
import 'firestore_service.dart';
import 'models.dart';
import 'study_page.dart';
import 'tombol_kartu_ai.dart'; // [BARU]

class DeckPage extends StatelessWidget {
  final Deck deck;
  const DeckPage({super.key, required this.deck});

  Future<void> _add(BuildContext context, FirestoreService service) async {
    final v = await showFormDialog(
      context,
      title: 'Kartu baru',
      labels: ['Pertanyaan', 'Jawaban'],
      confirmText: 'Tambah',
    );
    if (v != null) await service.addCard(deck.id, v[0], v[1]);
  }

  Future<void> _edit(
      BuildContext context, FirestoreService service, Flashcard card) async {
    final v = await showFormDialog(
      context,
      title: 'Ubah kartu',
      labels: ['Pertanyaan', 'Jawaban'],
      initial: [card.question, card.answer],
    );
    if (v != null) await service.updateCard(deck.id, card.id, v[0], v[1]);
  }

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Flashcard>>(
      stream: service.cards(deck.id),
      builder: (context, snap) {
        final cards = snap.data ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Text(deck.title),
            // [BARU] Tombol "Buat kartu dengan AI" di bilah atas
            actions: [
              TombolKartuAi(
                ikonSaja: true,
                onSimpan: (pertanyaan, jawaban) async {
                  await service.addCard(deck.id, pertanyaan, jawaban);
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _add(context, service),
            icon: const Icon(Icons.add),
            label: const Text('Kartu'),
          ),
          bottomNavigationBar: cards.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              StudyPage(title: deck.title, cards: cards),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: Text('Belajar (${cards.length} kartu)'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52)),
                    ),
                  ),
                ),
          body: Builder(builder: (_) {
            if (snap.hasError) {
              return Center(child: Text('Gagal memuat: ${snap.error}'));
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (cards.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.note_add_outlined,
                        size: 72, color: scheme.outline),
                    const SizedBox(height: 12),
                    const Text('Belum ada kartu. Ketuk "Kartu" untuk menambah.'),
                    // [BARU] Tombol AI juga muncul saat deck masih kosong
                    const SizedBox(height: 12),
                    TombolKartuAi(
                      onSimpan: (pertanyaan, jawaban) async {
                        await service.addCard(deck.id, pertanyaan, jawaban);
                      },
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: cards.length,
              itemBuilder: (context, i) {
                final card = cards[i];
                return Dismissible(
                  key: ValueKey(card.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.delete, color: scheme.onErrorContainer),
                  ),
                  confirmDismiss: (_) => showConfirmDialog(
                    context,
                    title: 'Hapus kartu?',
                    message: 'Kartu "${card.question}" akan dihapus.',
                  ),
                  onDismissed: (_) => service.deleteCard(deck.id, card.id),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(card.question,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(card.answer,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(context, service, card),
                    ),
                  ),
                );
              },
            );
          }),
        );
      },
    );
  }
}