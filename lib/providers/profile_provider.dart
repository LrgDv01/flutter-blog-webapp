import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';
import 'package:flutter_blog_webapp/models/profile.dart';

class ProfilesNotifier extends StateNotifier<Map<String, Profile>> {
  ProfilesNotifier() : super({}) {
    _fetchAllProfiles();
  }

  Future<void> _fetchAllProfiles() async {
    final data = await supabase
        .from('profiles')
        .select('id, user_id, display_name, avatar_url');

    final map = <String, Profile>{};
    for (final row in data) {
      final profile = Profile.fromJson(row);
      map[profile.userId] = profile;
    }
    state = map;
  }

  Profile? getProfile(String userId) => state[userId];

  String getDisplayName(String userId) =>
      state[userId]?.displayName ?? 'Anonymous';
}

final profilesProvider =
    StateNotifierProvider<ProfilesNotifier, Map<String, Profile>>(
  (ref) => ProfilesNotifier(),
);
