import 'package:flutter/material.dart';

import '../models/board.dart' as models;
import 'add_card_dialog.dart';
import 'card_widget.dart';

class KanbanColumn extends StatelessWidget {
  final models.BoardColumn column;
  final List<models.BoardCard> cards;
  final Function(models.CardCreate) onAddCard;
  final Function(String, Map<String, dynamic>) onUpdateCard;
  final Function(String, String, int) onMoveCard;
  final Function(String) onDeleteCard;
  final Function(Map<String, dynamic>) onUpdateColumn;
  final VoidCallback onDeleteColumn;

  const KanbanColumn({
    super.key,
    required this.column,
    required this.cards,
    required this.onAddCard,
    required this.onUpdateCard,
    required this.onMoveCard,
    required this.onDeleteCard,
    required this.onUpdateColumn,
    required this.onDeleteColumn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Card(
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Column header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(int.parse(column.color.replaceFirst('#', '0xFF'))).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(int.parse(column.color.replaceFirst('#', '0xFF'))),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      column.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _showEditColumnDialog(context);
                      if (value == 'delete') onDeleteColumn();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Cards list
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                child: cards.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.note_add_outlined,
                              size: 32,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No cards yet',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ReorderableListView.builder(
                        itemCount: cards.length,
                        onReorder: (oldIndex, newIndex) {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }
                          final card = cards[oldIndex];
                          onMoveCard(card.id, column.id, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final card = cards[index];
                          return CardWidget(
                            key: ValueKey(card.id),
                            card: card,
                            onUpdate: (updates) => onUpdateCard(card.id, updates),
                            onDelete: () => onDeleteCard(card.id),
                          );
                        },
                      ),
              ),
            ),
            // Add card button
            Container(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton.icon(
                onPressed: () => _showAddCardDialog(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Card'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddCardDialog(
        onAddCard: onAddCard,
      ),
    );
  }

  void _showEditColumnDialog(BuildContext context) {
    final nameController = TextEditingController(text: column.name);
    String selectedColor = column.color;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Column'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Column Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedColor,
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
                  selectedColor = value;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onUpdateColumn({
                'name': nameController.text,
                'color': selectedColor,
              });
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
