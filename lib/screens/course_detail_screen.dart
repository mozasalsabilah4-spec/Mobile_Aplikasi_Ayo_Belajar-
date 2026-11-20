import 'package:flutter/material.dart';
import '../models/flashcard_model.dart';
import 'study_session_screen.dart';

class CourseDetailScreen extends StatelessWidget {
  final Course course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(course.title),
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Chip Pilihan Kategori Kartu
            Row(
              children: [
                FilterChip(
                  label: const Text('Semua'),
                  selected: true,
                  onSelected: (_) {},
                  selectedColor: const Color(0xFF6C5CE7).withOpacity(0.2),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Belum Hafal'),
                  selected: false,
                  onSelected: (_) {},
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Hafal'),
                  selected: false,
                  onSelected: (_) {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Daftar Kartu (ListView yang dibungkus Expanded)
            Expanded(
              child: ListView.builder(
                itemCount: course.cards.length,
                itemBuilder: (context, index) {
                  final card = course.cards[index];
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text(
                        card.question,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: card.isMastered 
                              ? Colors.green.withOpacity(0.15) 
                              : Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          card.isMastered ? 'Hafal' : 'Belum',
                          style: TextStyle(
                            color: card.isMastered ? Colors.green[700] : Colors.red[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 12),

            // Tombol Mulai Latihan Hafalan
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudySessionScreen(course: course),
                    ),
                  );
                },
                child: const Text(
                  'Mulai Latihan Hafalan',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}