import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/board.dart' as models;
import '../../providers/board_provider.dart';
import '../../widgets/add_column_dialog.dart';
import '../../widgets/kanban_column.dart';

class BoardDetailScreen extends ConsumerStatefulWidget {
  final String boardId;

  const BoardDetailScreen({
    super.key,
    required this.boardId,
  });

  @override
  ConsumerState<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends ConsumerState<BoardDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final boardState = ref.watch(boardStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(boardState.currentBoard?.name ?? 'Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddColumnDialog(context),
            tooltip: 'Add Column',
          ),
        ],
      ),
      body: boardState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : boardState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading board',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        boardState.error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(boardStateProvider.notifier).clearError();
                          ref.read(boardStateProvider.notifier).selectBoard(widget.boardId);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : boardState.columns.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.view_column_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No columns yet',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first column to organize your tasks',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => _showAddColumnDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Column'),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      color: Colors.grey[100],
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...boardState.columns.map((column) {
                              final cards = boardState.cardsByColumn[column.id] ?? [];
                              return SizedBox(
                                width: 300,
                                child: KanbanColumn(
                                  column: column,
                                  cards: cards,
                                  onAddCard: (cardCreate) {
                                    ref.read(boardStateProvider.notifier).createCard(
                                      column.id,
                                      cardCreate,
                                    );
                                  },
                                  onUpdateCard: (cardId, updates) {
                                    ref.read(boardStateProvider.notifier).updateCard(
                                      cardId,
                                      updates,
                                    );
                                  },
                                  onMoveCard: (cardId, newColumnId, newPosition) {
                                    ref.read(boardStateProvider.notifier).moveCard(
                                      cardId,
                                      newColumnId,
                                      newPosition,
                                    );
                                  },
                                  onDeleteCard: (cardId) {
                                    ref.read(boardStateProvider.notifier).deleteCard(cardId);
                                  },
                                  onUpdateColumn: (updates) {
                                    ref.read(boardStateProvider.notifier).updateColumn(
                                      column.id,
                                      updates,
                                    );
                                  },
                                  onDeleteColumn: () {
                                    _showDeleteColumnDialog(context, column);
                                  },
                                ),
                              );
                            }),
                            // Add column button
                            Container(
                              width: 300,
                              padding: const EdgeInsets.all(16),
                              child: Card(
                                child: InkWell(
                                  onTap: () => _showAddColumnDialog(context),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 200,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                                        style: BorderStyle.solid,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add,
                                          size: 32,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Add Column',
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(boardStateProvider.notifier).selectBoard(widget.boardId);
    });
  }

  void _showAddColumnDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddColumnDialog(),
    );
  }

  void _showDeleteColumnDialog(BuildContext context, models.BoardColumn column) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Column'),
        content: Text('Are you sure you want to delete "${column.name}"? This will also delete all cards in this column.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(boardStateProvider.notifier).deleteColumn(column.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
