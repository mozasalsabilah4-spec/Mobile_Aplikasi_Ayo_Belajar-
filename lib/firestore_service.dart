import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models.dart';

/// Struktur data: users/{uid}/decks/{deckId}/cards/{cardId}
class FirestoreService {
  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _decks =>
      _db.collection('users').doc(_uid).collection('decks');

  CollectionReference<Map<String, dynamic>> _cards(String deckId) =>
      _decks.doc(deckId).collection('cards');

  // ---------- Deck ----------
  Stream<List<Deck>> decks() => _decks
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Deck.fromDoc).toList());

  Future<void> addDeck(String title) => _decks.add({
        'title': title,
        'cardCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> renameDeck(String deckId, String title) =>
      _decks.doc(deckId).update({'title': title});

  Future<void> deleteDeck(String deckId) async {
    final cards = await _cards(deckId).get();
    final batch = _db.batch();
    for (final c in cards.docs) {
      batch.delete(c.reference);
    }
    batch.delete(_decks.doc(deckId));
    await batch.commit();
  }

  // ---------- Kartu ----------
  Stream<List<Flashcard>> cards(String deckId) => _cards(deckId)
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(Flashcard.fromDoc).toList());

  Future<void> addCard(String deckId, String question, String answer) {
    final batch = _db.batch();
    batch.set(_cards(deckId).doc(), {
      'question': question,
      'answer': answer,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_decks.doc(deckId), {'cardCount': FieldValue.increment(1)});
    return batch.commit();
  }

  Future<void> updateCard(
          String deckId, String cardId, String question, String answer) =>
      _cards(deckId).doc(cardId).update({
        'question': question,
        'answer': answer,
      });

  Future<void> deleteCard(String deckId, String cardId) {
    final batch = _db.batch();
    batch.delete(_cards(deckId).doc(cardId));
    batch.update(_decks.doc(deckId), {'cardCount': FieldValue.increment(-1)});
    return batch.commit();
  }
}