import 'package:flutter/material.dart';

/// Dialog isian. Mengembalikan daftar nilai (sudah di-trim) atau null jika batal.
Future<List<String>?> showFormDialog(
  BuildContext context, {
  required String title,
  required List<String> labels,
  List<String>? initial,
  String confirmText = 'Simpan',
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _FormDialog(
      title: title,
      labels: labels,
      initial: initial,
      confirmText: confirmText,
    ),
  );
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Hapus',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _FormDialog extends StatefulWidget {
  final String title;
  final List<String> labels;
  final List<String>? initial;
  final String confirmText;

  const _FormDialog({
    required this.title,
    required this.labels,
    required this.initial,
    required this.confirmText,
  });

  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  late final List<TextEditingController> _controllers;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.labels.length,
      (i) => TextEditingController(text: widget.initial?[i] ?? ''),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final values = _controllers.map((c) => c.text.trim()).toList();
    if (values.any((v) => v.isEmpty)) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _controllers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 4),
                child: TextField(
                  controller: _controllers[i],
                  autofocus: i == 0,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: widget.labels[i],
                    border: const OutlineInputBorder(),
                    errorText: _showError && _controllers[i].text.trim().isEmpty
                        ? 'Tidak boleh kosong'
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmText)),
      ],
    );
  }
}