import 'package:flutter/material.dart';

import '../models/board.dart' as models;

class CardWidget extends StatelessWidget {
  final models.BoardCard card;
  final Function(Map<String, dynamic>) onUpdate;
  final VoidCallback onDelete;

  const CardWidget({
    super.key,
    required this.card,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 1,
        child: InkWell(
          onTap: () => _showCardDetailsDialog(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Color(int.parse(card.color.replaceFirst('#', '0xFF'))).withOpacity(0.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (card.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    card.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (card.dueDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: _getDueDateColor(context, card.dueDate!),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDueDate(card.dueDate!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getDueDateColor(context, card.dueDate!),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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

  Color _getDueDateColor(BuildContext context, DateTime dueDate) {
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

  void _showCardDetailsDialog(BuildContext context) {
    final titleController = TextEditingController(text: card.title);
    final descriptionController = TextEditingController(text: card.description);
    DateTime? selectedDate = card.dueDate;
    String selectedColor = card.color;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Card'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedColor,
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
                              selectedColor = value;
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
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() {
                              selectedDate = date;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          selectedDate != null
                              ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                              : 'Due Date',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                if (selectedDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: _getDueDateColor(context, selectedDate!),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDueDate(selectedDate!),
                        style: TextStyle(
                          color: _getDueDateColor(context, selectedDate!),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          setState(() {
                            selectedDate = null;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                onUpdate({
                  'title': titleController.text,
                  'description': descriptionController.text,
                  'color': selectedColor,
                  'due_date': selectedDate?.toIso8601String(),
                });
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
