import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blog_webapp/providers/auth_provider.dart';
import 'package:flutter_blog_webapp/providers/posts_provider.dart';
import 'package:flutter_blog_webapp/providers/profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _refreshPosts(WidgetRef ref) async {
    await ref.read(postsProvider.notifier).fetchPosts();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch providers here so this page redraws on auth/feed/profile updates.
    final authState = ref.watch(authProvider);
    final postsState = ref.watch(postsProvider);
    final profiles = ref.watch(profilesProvider);
    final currentUserId = authState.user?.id;
    final currentProfile = currentUserId == null
        ? null
        : profiles[currentUserId];
    final metadataDisplayName =
        authState.user?.userMetadata?['display_name'] as String?;
    final currentDisplayName =
        currentProfile?.displayName?.trim().isNotEmpty == true
        ? currentProfile!.displayName!
        : (metadataDisplayName ?? 'My Profile');
    final posts = postsState.posts;
    // Keep existing posts visible even when refresh fails.
    final showInlineError = postsState.error != null && posts.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Flutter Blog',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                currentDisplayName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: CircleAvatar(
              backgroundImage: currentProfile?.avatarUrl != null
                  ? CachedNetworkImageProvider(currentProfile!.avatarUrl!)
                  : null,
              child: currentProfile?.avatarUrl == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            onPressed: () => context.go('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/create-post'),
        child: const Icon(Icons.add),
      ),
      body: Builder(
        builder: (context) {
          // First load state.
          if (postsState.isLoading && posts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Full-page error when there is nothing cached to render.
          if (postsState.error != null && posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Failed to load posts\n${postsState.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          ref.read(postsProvider.notifier).fetchPosts(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (posts.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => _refreshPosts(ref),
              // AlwaysScrollable allows pull-to-refresh on empty lists.
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 220),
                  Center(child: Text('No posts yet. Create one!')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _refreshPosts(ref),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              itemCount: posts.length + (showInlineError ? 1 : 0),
              itemBuilder: (context, index) {
                // Inline refresh error banner above the current list.
                if (showInlineError && index == 0) {
                  return Card(
                    color: Colors.red.shade50,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                      ),
                      title: Text(
                        'Could not refresh latest data: ${postsState.error}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  );
                }

                // Shift by one when the inline error banner takes the first row.
                final actualIndex = showInlineError ? index - 1 : index;
                final post = posts[actualIndex];
                // Current user's posts are labeled as "You" for quick scanning.
                final isMyPost = post.userId == authState.user?.id;
                // For non-anonymous posts, resolve the author's display name from the profiles provider.
                final resolvedDisplayName =
                    profiles[post.userId]?.displayName ?? 'Unknown User';
                final authorName = isMyPost
                    ? (post.isAnonymous ? 'You (Anonymous)' : 'You')
                    : (post.isAnonymous ? 'Anonymous' : resolvedDisplayName);

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.go('/post/${post.id}'),
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Show a short preview instead of the full article text.
                              Text(
                                post.content,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(height: 1.4),
                              ),
                              const SizedBox(height: 8),
                              // Metadata line keeps author/date compact in list cards.
                              Text(
                                authorName == 'You' ||
                                        authorName == 'You (Anonymous)'
                                    ? '$authorName | Posted ${post.createdAt.toString().substring(0, 10)}'
                                    : 'By $authorName | Posted ${post.createdAt.toString().substring(0, 10)}',
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
        },
      ),
    );
  }
}
