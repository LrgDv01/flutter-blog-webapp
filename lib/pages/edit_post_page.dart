// Similar to CreatePostScreen but pre-filled and uses updatePost
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Prefill from existing post
    final post = ref
        .read(postsProvider)
        .firstWhere((p) => p.id == widget.postId);
    _titleController.text = post.title;
    _contentController.text = post.content;
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (image != null && mounted) {
      setState(() => _selectedImage = image);
    }
  }

  Future<void> _updatePost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    String? uploadedUrl;

    try {
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final userId = supabase.auth.currentUser!.id;
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_selectedImage!.name}';

        await supabase.storage
            .from('post_images')
            .uploadBinary('$userId/$fileName', bytes);

        uploadedUrl = supabase.storage
            .from('post_images')
            .getPublicUrl('$userId/$fileName');
      }

      await ref
          .read(postsProvider.notifier)
          .updatePost(
            postId: widget.postId,
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            imageUrl: uploadedUrl, // Pass new image URL if updated
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated successfully')),
        );
        context.replace('/home'); // Navigate back to home after update
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update post: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: 'Content'),
                maxLines: 5,
                validator: (value) =>
                    value!.isEmpty ? 'Please enter content' : null,
              ),
              const SizedBox(height: 16),
              if (_selectedImage != null)
                Image.file(
                  File(_selectedImage!.path),
                  height: 200,
                  fit: BoxFit.cover,
                ),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('Change Image'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _updatePost,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Update Post'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
