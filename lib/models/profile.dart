class Profile {
  // Unique identifier for the profile
  final String id;
  final String userId;
  final String? displayName;
  final String? avatarUrl;

  // Constructor to initialize all fields of the Profile class
  Profile({
    required this.id,
    required this.userId,
    this.displayName,
    this.avatarUrl,
  });

  // Factory constructor to create a Profile instance from JSON data
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
