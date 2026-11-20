class Flashcard {
  final String id;
  final String question;
  final String answer;
  bool isMastered;

  Flashcard({
    required this.id,
    required this.question,
    required this.answer,
    this.isMastered = false,
  });
}

class Course {
  final String id;
  final String title;
  final List<Flashcard> cards;

  Course({
    required this.id,
    required this.title,
    required this.cards,
  });

  int get masteredCount => cards.where((c) => c.isMastered).length;
  int get totalCount => cards.length;
}

// Global data agar bisa diakses dan ditambah dari halaman mana saja
class AppData {
  static List<Course> courses = [];
}