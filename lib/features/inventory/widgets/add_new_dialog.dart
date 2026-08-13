import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';

/// Reusable dialog for adding new items/categories in the inventory module.
class AddNewDialog extends ConsumerStatefulWidget {
  final String title;
  final String hintText;
  final Future<void> Function(String name) onAdd;

  const AddNewDialog({
    super.key,
    required this.title,
    this.hintText = 'İsim',
    required this.onAdd,
  });

  @override
  ConsumerState<AddNewDialog> createState() => _AddNewDialogState();
}

class _AddNewDialogState extends ConsumerState<AddNewDialog> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        style:  TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(hintText: widget.hintText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _loading
              ? null
              : () async {
                  final text = _ctrl.text.trim();
                  if (text.isEmpty) return;
                  setState(() => _loading = true);
                  try {
                    await widget.onAdd(text);
                    if (context.mounted) Navigator.pop(context);
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
          child: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Ekle'),
        ),
      ],
    );
  }
}