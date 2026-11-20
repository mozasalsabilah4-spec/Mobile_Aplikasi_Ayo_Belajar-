import 'package:flutter/material.dart';
import '../models/flashcard_model.dart';

class SummaryScreen extends StatelessWidget {
  final Course course;

  const SummaryScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    int mastered = course.masteredCount;
    int unmastered = course.totalCount - mastered;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Sesi Selesai'), backgroundColor: const Color(0xFF6C5CE7), foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: Color(0xFF00B894)),
            const SizedBox(height: 16),
            Text(course.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard('Hafal', '$mastered', const Color(0xFF00B894)),
                _buildStatCard('Belum Hafal', '$unmastered', const Color(0xFFFF7675)),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali ke Mata Kuliah', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(count, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}