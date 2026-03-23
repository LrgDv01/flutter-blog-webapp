import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_blog_webapp/providers/posts_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  // Form and input controllers
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _picker = ImagePicker();

  // Image and loading state
  XFile? _selectedImage;
  bool _isUploading = false;
  bool _postAsAnonymous = false;

  void _handleBackNavigation() => context.go('/home');

  // Pick image from gallery
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

  // Upload image and create post
  Future<void> _createPost() async {
    // Validate form before proceeding
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);
    String? uploadedUrl;

    try {
      // Upload image to storage if selected
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final userId = supabase.auth.currentUser!.id;
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_selectedImage!.name}';

        // Upload binary data to Supabase storage
        await supabase.storage
            .from('post_images')
            .uploadBinary('$userId/$fileName', bytes);

        // Get public URL of uploaded image
        uploadedUrl = supabase.storage
            .from('post_images')
            .getPublicUrl('$userId/$fileName');
      }

      // Create post with title, content, and image URL
      await ref
          .read(postsProvider.notifier)
          .createPost(
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            imageUrl: uploadedUrl,
            isAnonymous: _postAsAnonymous,
          );

      // Show success and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully')),
        );
        context.go('/home');
      }
    } catch (e) {
      // Handle errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: ${e.toString()}')),
        );
      }
    } finally {
      // Reset loading state
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Return to previous page when possible, otherwise fall back to home.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 30),
          onPressed: _handleBackNavigation,
        ),
        title: const Center(child: Text('Create Post')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title input field
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Content input field
            TextFormField(
              controller: _contentController,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),

            // Image picker button
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(
                _selectedImage == null ? 'Add Cover Image' : 'Change Image',
              ),
            ),

            // Display selected image preview
            if (_selectedImage != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _selectedImage!.path,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, size: 80),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Anonymous posting option
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Post anonymously'),
              subtitle: const Text('Your name will appear as Anonymous'),
              value: _postAsAnonymous,
              onChanged: _isUploading
                  ? null
                  : (value) => setState(() => _postAsAnonymous = value),
            ),

            const SizedBox(height: 32),

            // Publish button with loading indicator
            FilledButton(
              onPressed: _isUploading ? null : _createPost,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Publish', style: TextStyle(fontSize: 17)),
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
