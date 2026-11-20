import 'package:flutter/material.dart';
import '../models/flashcard_model.dart';
import 'summary_screen.dart';

class StudySessionScreen extends StatefulWidget {
  final Course course;

  const StudySessionScreen({super.key, required this.course});

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  int _currentIndex = 0;
  bool _showAnswer = false;

  void _nextCard(bool mastered) {
    widget.course.cards[_currentIndex].isMastered = mastered;
    if (_currentIndex < widget.course.cards.length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SummaryScreen(course: widget.course)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.course.cards[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('${course.title} (${_currentIndex + 1}/${widget.course.cards.length})'),
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showAnswer = !_showAnswer),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15)],
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _showAnswer ? 'JAWABAN' : 'PERTANYAAN',
                            style: TextStyle(color: Colors.grey[400], letterSpacing: 1.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _showAnswer ? card.answer : card.question,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 30),
                          const Text('Ketuk kartu untuk membalik', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7675), padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () => _nextCard(false),
                    child: const Text('Belum Hafal', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B894), padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () => _nextCard(true),
                    child: const Text('Hafal', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Course get course => widget.course;
}