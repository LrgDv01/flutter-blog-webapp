import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';
import 'package:flutter_blog_webapp/models/profile.dart';
import 'package:flutter_blog_webapp/utils/error_utils.dart';

class ProfilesNotifier extends StateNotifier<Map<String, Profile>> {
  ProfilesNotifier() : super({}) {
    // Warm the profile cache when the provider is first created.
    _fetchAllProfiles();
  }

  Future<void> _fetchAllProfiles({bool rethrowOnError = false}) async {
    try {
      // Load profile fields used by post/comment author display.
      final data = await supabase
          .from('profiles')
          .select(
            'id, user_id, display_name, avatar_url, created_at, updated_at',
          );

      // Key profiles by user id for quick lookups across the app.
      final map = <String, Profile>{};
      for (final row in data) {
        final profile = Profile.fromJson(Map<String, dynamic>.from(row));
        map[profile.userId] = profile;
      }
      state = map;
    } catch (e) {
      // Initial cache warm-up can fail quietly; explicit refreshes can opt in to errors.
      if (rethrowOnError) {
        throw Exception(
          formatAppError(e, fallbackMessage: 'Failed to refresh profiles.'),
        );
      }
    }
  }

  // Read a single cached profile without exposing the map shape to callers.
  Profile? getProfile(String userId) => state[userId];

  // Keep UI labels readable while a profile is missing.
  String getDisplayName(String userId) =>
      state[userId]?.displayName ?? 'Anonymous';

  // Allow profile updates to be made from the UI, but keep the cache in sync by re-fetching all profiles after an update.
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? avatarUrl,
    bool clearAvatar = false,
  }) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      // Check whether this user already has a profile row to update.
      final existingProfile = await supabase
          .from('profiles')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existingProfile == null) {
        final insertData = <String, dynamic>{
          'user_id': userId,
          'display_name': ?displayName,
          'updated_at': timestamp,
        };

        // New profiles can be created with or without an avatar, but existing avatars must be explicitly cleared by the user.
        if (clearAvatar) {
          insertData['avatar_url'] = null;
        } else if (avatarUrl != null) {
          insertData['avatar_url'] = avatarUrl;
        }

        await supabase.from('profiles').insert(insertData);
      } else {
        final updateData = <String, dynamic>{'updated_at': timestamp};

        if (displayName != null) {
          updateData['display_name'] = displayName;
        }
        
        if (clearAvatar) {
          updateData['avatar_url'] = null;
        } else if (avatarUrl != null) {
          updateData['avatar_url'] = avatarUrl;
        }

        await supabase
            .from('profiles')
            .update(updateData)
            .eq('user_id', userId);
      }
      // Refresh the entire cache to reflect the updated profile across the app.
      await _fetchAllProfiles(rethrowOnError: true);
    } catch (e) {
      // Bubble up formatted errors so pages can show user-friendly messages.
      throw Exception(
        formatAppError(e, fallbackMessage: 'Failed to update profile.'),
      );
    }
  }
}

// Shared profile cache for resolving author details in the UI.
final profilesProvider =
    StateNotifierProvider<ProfilesNotifier, Map<String, Profile>>(
      (ref) => ProfilesNotifier(),
    );
