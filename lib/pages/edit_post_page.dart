import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_blog_webapp/providers/posts_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';

class EditPostPage extends ConsumerStatefulWidget {
  final String postId;
  const EditPostPage({super.key, required this.postId});

  @override
  ConsumerState<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends ConsumerState<EditPostPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  final _picker = ImagePicker();
  XFile? _newImageFile;
  String? _existingImageUrl;
  bool _removeImage = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final post = ref.read(postsProvider).firstWhere(
      (p) => p.id == widget.postId,
      orElse: () => throw Exception('Post not found'),
    );

    _titleController = TextEditingController(text: post.title);
    _contentController = TextEditingController(text: post.content);
    _existingImageUrl = post.imageUrl;
  }

  Future<void> _pickNewImage() async {
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

    String? finalImageUrl = _existingImageUrl;

    try {
      // Case 1: User wants to remove the image
      if (_removeImage) {
        finalImageUrl = null;
      }
      // Case 2: User picked a new image → upload it
      else if (_newImageFile != null) {
        final bytes = await _newImageFile!.readAsBytes();
        final userId = supabase.auth.currentUser!.id;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_newImageFile!.name}';

        await supabase.storage
            .from('post_images')
            .uploadBinary('$userId/$fileName', bytes);

        finalImageUrl = supabase.storage
            .from('post_images')
            .getPublicUrl('$userId/$fileName');
      }
      // Case 3: Keep existing image → do nothing

      await ref.read(postsProvider.notifier).updatePost(
            postId: widget.postId,
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            imageUrl: finalImageUrl,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
      ),
      body: Form(
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
              validator: (v) => v!.trim().isEmpty ? 'Title is required' : null,
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
              validator: (v) => v!.trim().isEmpty ? 'Content is required' : null,
            ),
            const SizedBox(height: 24),

            const Text('Cover Image', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            if (_removeImage || (_existingImageUrl == null && _newImageFile == null))
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickNewImage,
                  icon: const Icon(Icons.upload),
                  label: const Text('Change Image'),
                ),
                if ((_existingImageUrl != null || _newImageFile != null) && !_removeImage)
                  OutlinedButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () => setState(() {
                              _removeImage = true;
                              _newImageFile = null;
                            }),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Remove Image', style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),

            const SizedBox(height: 32),

            FilledButton(
              onPressed: _isSaving ? null : _saveChanges,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              child: _isSaving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Save Changes', style: TextStyle(fontSize: 17)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}