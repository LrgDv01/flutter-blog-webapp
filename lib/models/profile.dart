class Profile {
  final String id;
  final String userId;
  final String? displayName;
  final String? avatarUrl;

  Profile({
    required this.id,
    required this.userId,
    this.displayName,
    this.avatarUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      userId: json['user_id'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
    );
  }
}