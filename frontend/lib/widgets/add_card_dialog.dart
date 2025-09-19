import 'package:flutter/material.dart';

import '../models/board.dart' as models;

class AddCardDialog extends StatefulWidget {
  final Function(models.CardCreate) onAddCard;

  const AddCardDialog({
    super.key,
    required this.onAddCard,
  });

  @override
  State<AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<AddCardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  String _selectedColor = '#FFFFFF';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Card'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedColor,
                      decoration: const InputDecoration(
                        labelText: 'Color',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: '#FFFFFF', child: Text('White')),
                        DropdownMenuItem(value: '#FEF3C7', child: Text('Yellow')),
                        DropdownMenuItem(value: '#D1FAE5', child: Text('Green')),
                        DropdownMenuItem(value: '#DBEAFE', child: Text('Blue')),
                        DropdownMenuItem(value: '#FEE2E2', child: Text('Red')),
                        DropdownMenuItem(value: '#E9D5FF', child: Text('Purple')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedColor = value;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            : 'Due Date',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              if (_selectedDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: _getDueDateColor(_selectedDate!),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDueDate(_selectedDate!),
                      style: TextStyle(
                        color: _getDueDateColor(_selectedDate!),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        setState(() {
                          _selectedDate = null;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onAddCard(models.CardCreate(
                title: _titleController.text,
                description: _descriptionController.text,
                color: _selectedColor,
                dueDate: _selectedDate,
              ));
              Navigator.of(context).pop();
            }
          },
          child: const Text('Add Card'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;

    if (difference < 0) {
      return 'Overdue by ${-difference} day${-difference == 1 ? '' : 's'}';
    } else if (difference == 0) {
      return 'Due today';
    } else if (difference == 1) {
      return 'Due tomorrow';
    } else if (difference <= 7) {
      return 'Due in $difference days';
    } else {
      return 'Due ${dueDate.day}/${dueDate.month}/${dueDate.year}';
    }
  }

  Color _getDueDateColor(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;

    if (difference < 0) {
      return Colors.red; // Overdue
    } else if (difference == 0) {
      return Colors.orange; // Due today
    } else if (difference <= 3) {
      return Colors.amber; // Due soon
    } else {
      return Colors.green; // Not urgent
    }
  }
}
