import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blog_webapp/providers/auth_provider.dart';
import 'package:flutter_blog_webapp/providers/posts_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Main home page widget extending ConsumerWidget for Riverpod state management
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch auth and posts state from providers
    final authState = ref.watch(authProvider);
    final posts = ref.watch(postsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Flutter Blog',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.enable('smcp')],
          ),
        ),
        actions: [
          // Logout button in app bar
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Sign out and redirect to login page
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      // Floating action button to create new post
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.replace('/create-post'),
        child: const Icon(Icons.add),
      ),
      // Main content area - show empty state or posts list
      body: posts.isEmpty
          // Empty state message when no posts exist
          ? const Center(child: Text('No posts yet. Create one!'))
          // Scrollable list of blog posts
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                // Tap to navigate to post details
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/post/${post.id}'),
                  // Card container for each post
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display post image if available
                        if (post.imageUrl != null)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: post.imageUrl!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        // Post title, content preview, author and date information
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Post title
                              Text(
                                post.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Post content preview (limited to 3 lines with ellipsis)
                              Text(
                                post.content,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(height: 1.4),
                              ),
                              const SizedBox(height: 8),
                              // Author name and post date
                              Text(
                                'By ${authState.user?.userMetadata?['display_name'] ?? 'You'} | Posted • ${post.createdAt.toString().substring(0, 10)}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
