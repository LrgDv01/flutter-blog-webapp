import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blog_webapp/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch authentication state to get user info and login status
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Blog'),
        actions: [
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Sign out the user
              await ref.read(authProvider.notifier).signOut();

              // Verify context is still mounted before navigation
              if (!context.mounted) return;

              // Navigate to login page
              context.go('/login');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display user's display name or email
            Text(
              'Welcome, ${authState.user?.userMetadata?['display_name'] ?? authState.user?.email}',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 16),
            const Text('Blog Home Screen'),
          ],
        ),
      ),
    );
  }
}
