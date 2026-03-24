import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_blog_webapp/models/post.dart';
import 'package:flutter_blog_webapp/providers/posts_provider.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';
import 'package:flutter_blog_webapp/utils/error_utils.dart';
import 'package:go_router/go_router.dart';

class EditPostPage extends ConsumerStatefulWidget {
  final String postId;
  const EditPostPage({super.key, required this.postId});

  @override
  ConsumerState<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends ConsumerState<EditPostPage> {
  // Form state and input controllers.
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _hasSeededFields = false;

  // Image edit state: keep existing, replace with new, or remove.
  final _picker = ImagePicker();
  XFile? _newImageFile;
  String? _existingImageUrl;
  bool _removeImage = false;
  bool _postAsAnonymous = false;
  bool _isSaving = false;

  Post? _findPost(List<Post> posts) {
    for (final post in posts) {
      if (post.id == widget.postId) return post;
    }

    return null;
  }

  void _seedForm(Post post) {
    if (_hasSeededFields) return;

    _titleController.text = post.title;
    _contentController.text = post.content;
    _existingImageUrl = post.imageUrl;
    _postAsAnonymous = post.isAnonymous;
    _hasSeededFields = true;
  }

  Future<void> _pickNewImage() async {
    // Pick a replacement image from gallery and cancel any remove flag.
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (image != null && mounted) {
      setState(() {
        _newImageFile = image;
        _removeImage = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // Default behavior: keep the existing image URL.
    String? finalImageUrl = _existingImageUrl;

    try {
      // Case 1: User wants to remove the image
      if (_removeImage) {
        finalImageUrl = null;
      }
      // Case 2: User picked a new image -> upload it
      else if (_newImageFile != null) {
        final currentUser = supabase.auth.currentUser;
        if (currentUser == null) {
          throw Exception('You must be logged in to edit a post.');
        }
        final bytes = await _newImageFile!.readAsBytes();
        final userId = currentUser.id;
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_newImageFile!.name}';

        await supabase.storage
            .from('post_images')
            .uploadBinary('$userId/$fileName', bytes);

        finalImageUrl = supabase.storage
            .from('post_images')
            .getPublicUrl('$userId/$fileName');
      }

      // Case 3: Keep existing image -> do nothing
      await ref
          .read(postsProvider.notifier)
          .updatePost(
            postId: widget.postId,
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            imageUrl: finalImageUrl,
            isAnonymous: _postAsAnonymous,
          );

      if (mounted) {
        // Return to previous screen after successful update.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated successfully')),
        );
        context.go('/post/${widget.postId}');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          e,
          fallbackMessage: 'Failed to update post. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final postsState = ref.watch(postsProvider);
    final post = _findPost(postsState.posts);

    if (post != null) {
      _seedForm(post);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/post/${widget.postId}'),
        ),
        title: const Center(child: Text('Edit Post')),
      ),
      body: post == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (postsState.isLoading)
                      const CircularProgressIndicator()
                    else ...[
                      Text(
                        postsState.error != null
                            ? postsState.error!
                            : 'Post not found.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: postsState.error != null
                            ? () => ref.read(postsProvider.notifier).fetchPosts()
                            : () => context.go('/home'),
                        child: Text(
                          postsState.error != null
                              ? 'Retry'
                              : 'Back to Home',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _contentController,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Content is required' : null,
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Cover Image',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  // Preview priority: removed -> new local selection -> existing remote image.
                  if (_removeImage ||
                      (_existingImageUrl == null && _newImageFile == null))
                    const Text('No image', style: TextStyle(color: Colors.grey))
                  else if (_newImageFile != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _newImageFile!.path,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else if (_existingImageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: _existingImageUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Actions for replacing or removing the current cover image.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isSaving ? null : _pickNewImage,
                        icon: const Icon(Icons.upload),
                        label: const Text('Change Image'),
                      ),
                      if ((_existingImageUrl != null || _newImageFile != null) &&
                          !_removeImage)
                        OutlinedButton.icon(
                          onPressed: _isSaving
                              ? null
                              : () => setState(() {
                                  _removeImage = true;
                                  _newImageFile = null;
                                }),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Remove Image',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Anonymous posting option
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Post anonymously'),
                    subtitle: const Text('Your name will appear as Anonymous'),
                    value: _postAsAnonymous,
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() => _postAsAnonymous = value),
                  ),

                  const SizedBox(height: 32),

                  // Save changes button with loading indicator
                  FilledButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(fontSize: 17),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  // Clean up controllers when the widget is disposed
  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
