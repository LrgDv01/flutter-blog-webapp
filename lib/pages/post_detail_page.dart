import 'package:flutter/material.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_blog_webapp/providers/posts_provider.dart';
import 'package:go_router/go_router.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  // Controllers and state for comment functionality
  final _commentController = TextEditingController();
  XFile? _selectedCommentImage;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Allow user to select an image from gallery
  Future<void> _pickCommentImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) setState(() => _selectedCommentImage = image);
  }

  // Upload comment with optional image to Supabase
  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    String? imageUrl;
    if (_selectedCommentImage != null) {
      // Upload image to storage
      final bytes = await _selectedCommentImage!.readAsBytes();
      final userId = supabase.auth.currentUser!.id;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedCommentImage!.name}';

      await supabase.storage.from('post_images').uploadBinary('$userId/$fileName', bytes);
      imageUrl = supabase.storage.from('post_images').getPublicUrl('$userId/$fileName');
    }

    // Add comment to database
    await ref.read(commentsProviderFamily(widget.postId).notifier).addComment(
          content: _commentController.text.trim(),
          imageUrl: imageUrl,
        );

    // Clear form after successful submission
    _commentController.clear();
    setState(() => _selectedCommentImage = null);
  }

  @override
  Widget build(BuildContext context) {
    // Watch post and comments data
    final postAsync = ref.watch(postsProvider).firstWhere((p) => p.id == widget.postId);
    final comments = ref.watch(commentsProviderFamily(widget.postId));

    // Check if current user is post owner
    final isOwner = postAsync.userId == supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Detail'),
        actions: [
          // Edit button for post owner
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.push('/edit-post/${widget.postId}'),
            ),
          // Delete button for post owner
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete),
                onPressed: () async {
                // Delete the post from the database
                await ref.read(postsProvider.notifier).deletePost(widget.postId);
                // Navigate back after successful deletion
                if (context.mounted) context.pop();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post title
            Text(postAsync.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Post image
            if (postAsync.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: postAsync.imageUrl!,
                  width: double.infinity,
                  height: 280,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            // Post content
            Text(postAsync.content, style: const TextStyle(fontSize: 16, height: 1.6)),
            const Divider(height: 40),

            // Comments Section
            const Text('Comments', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Display comments or empty state
            comments.isEmpty
                ? const Text('No comments yet. Be the first!')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: comments.length,
                    itemBuilder: (context, i) {
                      final c = comments[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          // Comment image if available
                          leading: c.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: c.imageUrl!,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : null,
                          // Comment content and author
                          title: Text(c.content),
                          subtitle: Text('by ${c.userId.substring(0, 8)}...'),
                        ),
                      );
                    },
                  ),

            const SizedBox(height: 24),

            // Comment input form
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Write a comment...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Image picker button
                OutlinedButton.icon(
                  onPressed: _pickCommentImage,
                  icon: const Icon(Icons.image),
                  label: Text(_selectedCommentImage == null ? 'Add image' : 'Change image'),
                ),
                const Spacer(),
                // Submit comment button
                FilledButton(
                  onPressed: _addComment,
                  child: const Text('Post Comment'),
                ),
              ],
            ),
            // Preview selected image
            if (_selectedCommentImage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Image.network(_selectedCommentImage!.path, height: 100),
              ),
          ],
        ),
      ),
    );
  }
}




