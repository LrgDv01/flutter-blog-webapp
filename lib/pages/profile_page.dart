import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_blog_webapp/providers/profile_provider.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _displayNameController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _newAvatar;
  bool _isSaving = false;
  bool _hasSeededDisplayName = false;

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) setState(() => _newAvatar = image);
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      final profiles = ref.read(profilesProvider);
      String? avatarUrl = profiles[userId]?.avatarUrl;

      // Upload new avatar if selected.
      if (_newAvatar != null) {
        final bytes = await _newAvatar!.readAsBytes();
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_newAvatar!.name}';

        await supabase.storage
            .from('avatars')
            .uploadBinary('$userId/$fileName', bytes);

        avatarUrl = supabase.storage
            .from('avatars')
            .getPublicUrl('$userId/$fileName');
      }

      await ref
          .read(profilesProvider.notifier)
          .updateProfile(
            userId: userId,
            displayName: _displayNameController.text.trim(),
            avatarUrl: avatarUrl,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser!;
    final profiles = ref.watch(profilesProvider);
    final profile = profiles[user.id];

    if (!_hasSeededDisplayName &&
        _displayNameController.text.isEmpty &&
        profile?.displayName != null) {
      _displayNameController.text = profile!.displayName!;
      _hasSeededDisplayName = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 70,
                  backgroundImage: profile?.avatarUrl != null
                      ? CachedNetworkImageProvider(profile!.avatarUrl!)
                      : null,
                  child: profile?.avatarUrl == null
                      ? const Icon(Icons.person, size: 60)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: FloatingActionButton.small(
                    onPressed: _pickAvatar,
                    child: const Icon(Icons.camera_alt),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Current email (read only)
            TextFormField(
              initialValue: user.email,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
            ),
            const SizedBox(height: 16),

            // Editable display name
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Changes', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
