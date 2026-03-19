class Profile {
  // Unique identifier for the profile
  final String id;
  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Constructor to initialize all fields of the Profile class
  Profile({
    required this.id,
    required this.userId,
    this.displayName,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  // Factory constructor to create a Profile instance from JSON data
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}
