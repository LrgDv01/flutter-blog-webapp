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
                  onTap: () => context.push('/post/${post.id}'),
                  // Card container for each post
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Post image if available (with caching and error handling)
                        if (post.imageUrl != null)
                          CachedNetworkImage(
                            imageUrl: post.imageUrl!,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        // Post details section
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
                              // Post content preview (truncated)
                              Text(
                                post.content,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              // Author name
                              Text(
                                'By ${authState.user?.userMetadata?['display_name'] ?? 'You'}',
                                style: const TextStyle(color: Colors.grey),
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
