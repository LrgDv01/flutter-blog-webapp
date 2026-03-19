import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';
import 'package:flutter_blog_webapp/models/profile.dart';

class ProfilesNotifier extends StateNotifier<Map<String, Profile>> {
  ProfilesNotifier() : super({}) {
    // Warm the profile cache when the provider is first created.
    _fetchAllProfiles();
  }

  Future<void> _fetchAllProfiles() async {
    // Load profile fields used by post/comment author display.
    final data = await supabase
        .from('profiles')
        .select('id, user_id, display_name, avatar_url, created_at, updated_at');

    // Key profiles by user id for quick lookups across the app.
    final map = <String, Profile>{};
    for (final row in data) {
      final profile = Profile.fromJson(row);
      map[profile.userId] = profile;
    }
    state = map;
  }

  Profile? getProfile(String userId) => state[userId];

  // Keep UI labels readable while a profile is missing.
  String getDisplayName(String userId) =>
      state[userId]?.displayName ?? 'Anonymous';
}

// Shared profile cache for resolving author details in the UI.
final profilesProvider =
    StateNotifierProvider<ProfilesNotifier, Map<String, Profile>>(
      (ref) => ProfilesNotifier(),
    );
