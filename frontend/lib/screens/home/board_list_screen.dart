import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/board.dart' as models;
import '../../providers/auth_provider.dart';
import '../../providers/board_provider.dart';
import '../../providers/subscription_provider.dart';
import 'board_detail_screen.dart';

class BoardCard extends StatelessWidget {
  final models.Board board;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const BoardCard({
    super.key,
    required this.board,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Color(int.parse(board.color.replaceFirst('#', '0xFF'))).withOpacity(0.1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Color(int.parse(board.color.replaceFirst('#', '0xFF'))),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete();
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
                const SizedBox(height: 8),
                Text(
                  board.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (board.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    board.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Created ${_formatDate(board.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) return 'today';
    if (difference == 1) return 'yesterday';
    if (difference < 7) return '$difference days ago';
    if (difference < 30) return '${(difference / 7).floor()} weeks ago';
    return '${(difference / 30).floor()} months ago';
  }
}

class BoardListScreen extends ConsumerWidget {
  const BoardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardState = ref.watch(boardStateProvider);
    final subscriptionState = ref.watch(subscriptionStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Boards'),
            if (subscriptionState.currentSubscription != null)
              Text(
                '${boardState.boards.length}/5 boards',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              )
            else
              Text(
                '${boardState.boards.length}/1 boards',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
          ],
        ),
        actions: [
          // Temporary debug buttons
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () async {
              try {
                final result = await ref.read(apiServiceProvider).debugSubscription();
                print('DEBUG RESULT: $result');
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Debug: $result')));
              } catch (e) {
                print('DEBUG ERROR: $e');
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Debug Error: $e')));
              }
            },
            tooltip: 'Debug Subscription',
          ),
          IconButton(
            icon: const Icon(Icons.payment),
            onPressed: () async {
              try {
                final result = await ref.read(apiServiceProvider).debugPaymentHistory();
                print('PAYMENT DEBUG RESULT: $result');
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Debug: $result')));
              } catch (e) {
                print('PAYMENT DEBUG ERROR: $e');
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Debug Error: $e')));
              }
            },
            tooltip: 'Debug Payment History',
          ),
          if (subscriptionState.currentSubscription == null)
            IconButton(
              icon: const Icon(Icons.upgrade),
              onPressed: () {
                // Navigate to subscription screen
                DefaultTabController.of(context).animateTo(1);
              },
              tooltip: 'Upgrade Plan',
            ),
        ],
      ),
      body: boardState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : (boardState.error != null)
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      boardState.error!.contains('subscription has expired')
                          ? Icons.payment_outlined
                          : Icons.error_outline,
                      size: 64,
                      color: boardState.error!.contains('subscription has expired')
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      boardState.error!.contains('subscription has expired')
                          ? 'Subscription Expired'
                          : 'Error loading boards',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      boardState.error!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (boardState.error!.contains('subscription has expired')) ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to subscription screen
                          DefaultTabController.of(context).animateTo(1);
                        },
                        icon: const Icon(Icons.upgrade),
                        label: const Text('Renew Subscription'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () async {
                          final notifier = ref.read(boardStateProvider.notifier);
                          notifier.clearError();
                          await notifier.loadBoards();
                        },
                        child: const Text('Try Again'),
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: () async {
                          final notifier = ref.read(boardStateProvider.notifier);
                          notifier.clearError();
                          await notifier.loadBoards();
                          if (ref.read(boardStateProvider).boards.isNotEmpty) {
                            notifier.clearError();
                          }
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.9,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: boardState.boards.length,
                      itemBuilder: (context, index) {
                        final board = boardState.boards[index];
                        return BoardCard(
                          board: board,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => BoardDetailScreen(boardId: board.id),
                              ),
                            );
                          },
                          onEdit: () => _showEditBoardDialog(context, ref, board),
                          onDelete: () => _showDeleteBoardDialog(context, ref, board),
                        );
                      },
                    ),
    );
  }

  void _showDeleteBoardDialog(BuildContext context, WidgetRef ref, models.Board board) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Board'),
        content: Text('Are you sure you want to delete "${board.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(boardStateProvider.notifier).deleteBoard(board.id);
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

  void _showEditBoardDialog(BuildContext context, WidgetRef ref, models.Board board) {
    final nameController = TextEditingController(text: board.name);
    final descriptionController = TextEditingController(text: board.description);
    String selectedColor = board.color;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Board'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Board Name',
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
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedColor,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  border: OutlineInputBorder(),
                ),
                items: const [
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(boardStateProvider.notifier).updateBoard(
                board.id,
                {
                  'name': nameController.text,
                  'description': descriptionController.text,
                  'color': selectedColor,
                },
              );
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
