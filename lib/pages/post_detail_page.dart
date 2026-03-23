import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_blog_webapp/models/comment.dart';
import 'package:flutter_blog_webapp/models/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blog_webapp/models/post.dart';
import 'package:flutter_blog_webapp/providers/posts_provider.dart';
import 'package:flutter_blog_webapp/providers/profile_provider.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _commentController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _selectedCommentImage;
  bool _isSubmittingComment = false;
  // Controls whether the next comment hides the user's name.
  bool _commentAsAnonymous = false;

  void _handleBackNavigation() => context.go('/home');

  // Finds the current post from the feed state if it is already loaded.
  Post? _findPost(List<Post> posts) {
    for (final post in posts) {
      if (post.id == widget.postId) return post;
    }
    return null;
  }

  // Refresh post + comments together for pull-to-refresh.
  Future<void> _refreshData() async {
    await Future.wait([
      ref.read(postsProvider.notifier).fetchPosts(),
      ref.read(commentsProviderFamily(widget.postId).notifier).fetchComments(),
    ]);
  }

  Future<void> _pickCommentImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );

    // Ignore if widget is gone or user canceled picker.
    if (!mounted || image == null) return;
    setState(() => _selectedCommentImage = image);
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Comment cannot be empty')));
      return;
    }

    setState(() => _isSubmittingComment = true);

    try {
      String? uploadedUrl;
      if (_selectedCommentImage != null) {
        // Upload selected comment image before inserting the comment row.
        final userId = supabase.auth.currentUser!.id;
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_selectedCommentImage!.name}';
        final bytes = await _selectedCommentImage!.readAsBytes();

        await supabase.storage
            .from('post_images')
            .uploadBinary('comments/$userId/$fileName', bytes);

        uploadedUrl = supabase.storage
            .from('post_images')
            .getPublicUrl('comments/$userId/$fileName');
      }

      await ref
          .read(commentsProviderFamily(widget.postId).notifier)
          .addComment(
            content: content,
            imageUrl: uploadedUrl,
            isAnonymous: _commentAsAnonymous,
          );

      if (!mounted) return;
      // Reset input state after a successful submit.
      _commentController.clear();
      setState(() => _selectedCommentImage = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add comment: $e')));
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  Future<void> _showDeletePostDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(postsProvider.notifier).deletePost(widget.postId);
      if (!mounted) return;
      _handleBackNavigation();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete post: $e')));
    }
  }

  Future<void> _showDeleteCommentDialog(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref
          .read(commentsProviderFamily(widget.postId).notifier)
          .deleteComment(commentId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete comment: $e')));
    }
  }

  Future<void> _showEditCommentDialog(Comment comment) async {
    final controller = TextEditingController(text: comment.content);
    var isSaving = false;
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit comment'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Comment',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final content = controller.text.trim();
                      if (content.isEmpty) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Comment cannot be empty'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await ref
                            .read(
                              commentsProviderFamily(widget.postId).notifier,
                            )
                            .updateComment(
                              commentId: comment.id,
                              content: content,
                            );

                        if (!mounted || !dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Comment updated successfully'),
                          ),
                        );
                      } catch (e) {
                        if (!mounted || !dialogContext.mounted) return;
                        setDialogState(() => isSaving = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to update comment: $e'),
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
  }

  ImageProvider<Object>? _buildCommentAvatar(Profile? profile, Comment comment) {
    final avatarUrl = profile?.avatarUrl?.trim();
    if (comment.isAnonymous || avatarUrl == null || avatarUrl.isEmpty) {
      return null;
    }

    return CachedNetworkImageProvider(avatarUrl);
  }

  @override
  Widget build(BuildContext context) {
    final postState = ref.watch(postsProvider);
    final commentsState = ref.watch(commentsProviderFamily(widget.postId));
    final profiles = ref.watch(profilesProvider);
    final post = _findPost(postState.posts);
    final currentUserId = supabase.auth.currentUser?.id;
    // Only the author can edit/delete the current post.
    final isOwner = post?.userId == currentUserId;
    final comments = commentsState.comments;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBackNavigation,
        ),
        title: const Text('Post Detail'),
        actions: [
          if (post != null && isOwner)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/edit-post/${widget.postId}'),
            ),
          if (post != null && isOwner)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeletePostDialog,
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (postState.isLoading && post == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (postState.error != null && post == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Failed to load post\n${postState.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _refreshData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Handle deleted/missing post IDs with a refreshable empty state.
          if (post == null) {
            return RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 220),
                  Center(child: Text('Post not found')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Posted ${post.createdAt.toString().substring(0, 16)}',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (post.imageUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: post.imageUrl!,
                      height: 280,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  post.content,
                  style: const TextStyle(fontSize: 16, height: 1.6),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Write a comment...',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Comment anonymously'),
                  subtitle: const Text('Your name will appear as Anonymous'),
                  value: _commentAsAnonymous,
                  onChanged: _isSubmittingComment
                      ? null
                      : (value) => setState(() => _commentAsAnonymous = value),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isSubmittingComment
                          ? null
                          : _pickCommentImage,
                      icon: const Icon(Icons.image),
                      label: Text(
                        _selectedCommentImage == null
                            ? 'Add image'
                            : 'Change image',
                      ),
                    ),
                    if (_selectedCommentImage != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Remove selected image',
                        onPressed: _isSubmittingComment
                            ? null
                            : () =>
                                  setState(() => _selectedCommentImage = null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                    const Spacer(),
                    FilledButton(
                      onPressed: _isSubmittingComment ? null : _addComment,
                      child: _isSubmittingComment
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Post Comment'),
                    ),
                  ],
                ),
                if (_selectedCommentImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _selectedCommentImage!.path,
                        height: 100,
                      ),
                    ),
                  ),
                const Divider(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('${comments.length}'),
                  ],
                ),
                const SizedBox(height: 12),
                // Keep a subtle inline error when stale comments are still available.
                if (commentsState.error != null && comments.isNotEmpty)
                  Card(
                    color: Colors.red.shade50,
                    child: ListTile(
                      leading: const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                      ),
                      title: Text(
                        'Could not refresh comments: ${commentsState.error}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                if (commentsState.isLoading && comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (commentsState.error != null && comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Text(
                          'Failed to load comments\n${commentsState.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(
                                  commentsProviderFamily(
                                    widget.postId,
                                  ).notifier,
                                )
                                .fetchComments();
                          },
                          child: const Text('Retry comments'),
                        ),
                      ],
                    ),
                  )
                else if (comments.isEmpty)
                  const Text('No comments yet. Be the first to comment.')
                else
                  ...comments.map((comment) {
                    final profile = profiles[comment.userId];
                    final isMyComment = comment.userId == currentUserId;
                    final profileDisplayName = profile?.displayName?.trim();
                    // Fall back to stored author name when profile cache misses.
                    final resolvedDisplayName =
                        (profileDisplayName?.isNotEmpty == true
                            ? profileDisplayName!
                            : null) ??
                        comment.authorName ??
                        'Unknown User';
                    final displayName = isMyComment
                        ? (comment.isAnonymous ? 'You (Anonymous)' : 'You')
                        : (comment.isAnonymous
                              ? 'Anonymous'
                              : resolvedDisplayName);
                    final avatarImage = _buildCommentAvatar(profile, comment);
                    // Only the comment owner can edit/remove their comment.
                    final canEdit = comment.userId == currentUserId;
                    final canDelete = comment.userId == currentUserId;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: avatarImage,
                                  child: avatarImage == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        comment.createdAt.toString().substring(
                                          0,
                                          16,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (canEdit)
                                  IconButton(
                                    tooltip: 'Edit comment',
                                    onPressed: () =>
                                        _showEditCommentDialog(comment),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                if (canDelete)
                                  IconButton(
                                    tooltip: 'Delete comment',
                                    onPressed: () =>
                                        _showDeleteCommentDialog(comment.id),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(comment.content),
                            if (comment.imageUrl != null) ...[
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: comment.imageUrl!,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
