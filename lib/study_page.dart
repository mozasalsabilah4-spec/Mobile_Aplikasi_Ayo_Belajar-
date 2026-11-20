import 'package:flutter/material.dart';

import 'models.dart';

class StudyPage extends StatefulWidget {
  final String title;
  final List<Flashcard> cards;

  const StudyPage({super.key, required this.title, required this.cards});

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  late List<Flashcard> _queue;
  List<Flashcard> _missed = [];
  int _index = 0;
  int _known = 0;
  bool _showAnswer = false;

  @override
  void initState() {
    super.initState();
    _start(widget.cards);
  }

  void _start(List<Flashcard> cards) {
    setState(() {
      _queue = [...cards]..shuffle();
      _missed = [];
      _index = 0;
      _known = 0;
      _showAnswer = false;
    });
  }

  void _answer(bool knew) {
    setState(() {
      if (knew) {
        _known++;
      } else {
        _missed.add(_queue[_index]);
      }
      _index++;
      _showAnswer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final finished = _index >= _queue.length;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: finished ? _buildResult(context) : _buildCard(context),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = _queue[_index];
    final text = _showAnswer ? card.answer : card.question;
    final bg = _showAnswer ? scheme.tertiaryContainer : scheme.primaryContainer;
    final fg =
        _showAnswer ? scheme.onTertiaryContainer : scheme.onPrimaryContainer;

    return Column(
      children: [
        LinearProgressIndicator(value: _index / _queue.length),
        const SizedBox(height: 8),
        Text('Kartu ${_index + 1} dari ${_queue.length}'),
        const SizedBox(height: 20),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _showAnswer = !_showAnswer),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Container(
                key: ValueKey('$_index-$_showAnswer'),
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showAnswer ? 'JAWABAN' : 'PERTANYAAN',
                      style: TextStyle(
                        color: fg,
                        letterSpacing: 2,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: fg,
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _showAnswer ? '' : 'Ketuk untuk melihat jawaban',
                      style: TextStyle(color: fg),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showAnswer ? () => _answer(false) : null,
                icon: const Icon(Icons.close),
                label: const Text('Belum tahu'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _showAnswer ? () => _answer(true) : null,
                icon: const Icon(Icons.check),
                label: const Text('Tahu'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final total = _queue.length;
    final percent = total == 0 ? 0 : (_known * 100 / total).round();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            percent == 100 ? Icons.emoji_events : Icons.task_alt,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('Sesi selesai!',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Kamu tahu $_known dari $total kartu ($percent%)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 32),
          if (_missed.isNotEmpty)
            FilledButton.icon(
              onPressed: () => _start(_missed),
              icon: const Icon(Icons.replay),
              label: Text('Ulangi yang belum tahu (${_missed.length})'),
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _start(widget.cards),
            icon: const Icon(Icons.shuffle),
            label: const Text('Ulangi semua kartu'),
            style:
                OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }
}