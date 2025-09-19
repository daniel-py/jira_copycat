import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/board.dart' as models;
import '../providers/board_provider.dart';

class AddColumnDialog extends StatefulWidget {
  const AddColumnDialog({super.key});

  @override
  State<AddColumnDialog> createState() => _AddColumnDialogState();
}

class _AddColumnDialogState extends State<AddColumnDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedColor = '#6B7280';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Column'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Column Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a column name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedColor,
              decoration: const InputDecoration(
                labelText: 'Color',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '#6B7280', child: Text('Gray')),
                DropdownMenuItem(value: '#3B82F6', child: Text('Blue')),
                DropdownMenuItem(value: '#10B981', child: Text('Green')),
                DropdownMenuItem(value: '#F59E0B', child: Text('Yellow')),
                DropdownMenuItem(value: '#EF4444', child: Text('Red')),
                DropdownMenuItem(value: '#8B5CF6', child: Text('Purple')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedColor = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        Consumer(
          builder: (context, ref, child) {
            return ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  ref.read(boardStateProvider.notifier).createColumn(
                    models.ColumnCreate(
                      name: _nameController.text,
                      color: _selectedColor,
                    ),
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add Column'),
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
