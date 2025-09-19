import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/board.dart' as models;
import '../../providers/auth_provider.dart';
import '../../providers/board_provider.dart';
import '../../providers/subscription_provider.dart';
import '../auth/login_screen.dart';
import '../billing/subscription_screen.dart';
import 'board_list_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Information',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(authState.user?.firstName ?? ''),
                      subtitle: Text(authState.user?.lastName ?? ''),
                    ),
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: Text(authState.user?.email ?? ''),
                    ),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text('Member since ${authState.user?.createdAt.year ?? ''}'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    // final boardState = ref.watch(boardStateProvider);
    // final subscriptionState = ref.watch(subscriptionStateProvider);

    if (!authState.isAuthenticated) {
      return const LoginScreen();
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          BoardListScreen(),
          SubscriptionScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Boards',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payment),
            label: 'Billing',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showCreateBoardDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only load data if user is authenticated
      final authState = ref.read(authStateProvider);
      if (authState.isAuthenticated) {
        ref.read(boardStateProvider.notifier).loadBoards();
        ref.read(subscriptionStateProvider.notifier).loadSubscriptionStatus();
      }
    });
  }

  void _showCreateBoardDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedColor = '#3B82F6';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Board'),
        content: Column(
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
                labelText: 'Description (Optional)',
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref.read(boardStateProvider.notifier).createBoard(
                  models.BoardCreate(
                    name: nameController.text,
                    description: descriptionController.text,
                    color: selectedColor,
                  ),
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
