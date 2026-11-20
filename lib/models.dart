import 'package:cloud_firestore/cloud_firestore.dart';

class Deck {
  final String id;
  final String title;
  final int cardCount;

  Deck({required this.id, required this.title, required this.cardCount});

  factory Deck.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Deck(
      id: doc.id,
      title: (m['title'] ?? '') as String,
      cardCount: (m['cardCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class Flashcard {
  final String id;
  final String question;
  final String answer;

  Flashcard({required this.id, required this.question, required this.answer});

  factory Flashcard.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Flashcard(
      id: doc.id,
      question: (m['question'] ?? '') as String,
      answer: (m['answer'] ?? '') as String,
    );
  }
}