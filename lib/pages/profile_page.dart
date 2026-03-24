import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_blog_webapp/models/profile.dart';
import 'package:flutter_blog_webapp/providers/profile_provider.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';
import 'package:flutter_blog_webapp/utils/error_utils.dart';
import 'package:go_router/go_router.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _displayNameController = TextEditingController();
  final _picker = ImagePicker();
  Uint8List? _newAvatarBytes;
  String? _newAvatarName;
  bool _isSaving = false;
  bool _isEditing = false;
  bool _hasSeededDisplayName = false;
  bool _removeCurrentAvatar = false;

  void _handleBackNavigation() => context.go('/home');

  void _beginEditing(Profile? profile) {
    setState(() {
      _isEditing = true;
      _newAvatarBytes = null;
      _newAvatarName = null;
      _removeCurrentAvatar = false;
      _displayNameController.text = profile?.displayName ?? '';
    });
  }

  void _cancelEditing(Profile? profile) {
    setState(() {
      _isEditing = false;
      _newAvatarBytes = null;
      _newAvatarName = null;
      _removeCurrentAvatar = false;
      _displayNameController.text = profile?.displayName ?? '';
    });
  }

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (!mounted || image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;

    setState(() {
      _newAvatarBytes = bytes;
      _newAvatarName = image.name;
      _removeCurrentAvatar = false;
    });
  }

  void _removeAvatar() {
    setState(() {
      _newAvatarBytes = null;
      _newAvatarName = null;
      _removeCurrentAvatar = true;
    });
  }

  ImageProvider<Object>? _buildAvatarImage(Profile? profile) {
    if (_removeCurrentAvatar) {
      return null;
    }

    if (_newAvatarBytes != null) {
      return MemoryImage(_newAvatarBytes!);
    }

    if (profile?.avatarUrl != null) {
      return CachedNetworkImageProvider(profile!.avatarUrl!);
    }

    return null;
  }

  Future<void> _saveProfile(Profile? profile) async {
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in to update your profile.');
      }
      final userId = currentUser.id;
      String? avatarUrl = profile?.avatarUrl;
      final shouldClearAvatar = _removeCurrentAvatar;

      // Upload new avatar if selected.
      if (_newAvatarBytes != null && _newAvatarName != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_newAvatarName!}';

        await supabase.storage
            .from('avatars')
            .uploadBinary('$userId/$fileName', _newAvatarBytes!);

        avatarUrl = supabase.storage
            .from('avatars')
            .getPublicUrl('$userId/$fileName');
      }

      await ref
          .read(profilesProvider.notifier)
          .updateProfile(
            userId: userId,
            displayName: displayName,
            avatarUrl: avatarUrl,
            clearAvatar: shouldClearAvatar,
          );

      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isSaving = false;
        _newAvatarBytes = null;
        _newAvatarName = null;
        _removeCurrentAvatar = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        e,
        fallbackMessage: 'Failed to update profile. Please try again.',
      );
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
    final user = supabase.auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'You are no longer signed in. Please log in again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final profiles = ref.watch(profilesProvider);
    final profile = profiles[user.id];
    final avatarImage = _buildAvatarImage(profile);
    final currentDisplayName = profile?.displayName?.trim().isNotEmpty == true
        ? profile!.displayName!
        : 'Anonymous User';
    final hasAvatar =
        _newAvatarBytes != null ||
        (!_removeCurrentAvatar && (profile?.avatarUrl?.isNotEmpty ?? false));

    if (!_hasSeededDisplayName &&
        _displayNameController.text.isEmpty &&
        profile?.displayName != null) {
      _displayNameController.text = profile!.displayName!;
      _hasSeededDisplayName = true;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBackNavigation,
        ),
        title: const Text('My Profile'),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : () => _cancelEditing(profile),
              child: const Text('Cancel'),
            )
          else
            IconButton(
              tooltip: 'Edit profile',
              onPressed: () => _beginEditing(profile),
              icon: const Icon(Icons.edit),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 70,
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? const Icon(Icons.person, size: 60)
                      : null,
                ),
                if (_isEditing) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _pickAvatar,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text(
                            _newAvatarBytes == null &&
                                    profile?.avatarUrl != null
                                ? 'Change Avatar'
                                : 'Choose Avatar',
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isSaving || !hasAvatar
                              ? null
                              : _removeAvatar,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove Avatar'),
                        ),
                      ],
                    ),
                  ),
                ],
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

            if (_isEditing)
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                ),
              )
            else
              TextFormField(
                initialValue: currentDisplayName,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
            const SizedBox(height: 32),

            if (_isEditing)
              FilledButton(
                onPressed: _isSaving ? null : () => _saveProfile(profile),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
