class Post {
  // Unique identifier for the post
  final String id;
  final String userId;
  final String title;
  final String content;
  final String? imageUrl;
  final bool isAnonymous;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Constructor to initialize all fields of the Post class
  Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    this.imageUrl,
    this.isAnonymous = false,
    required this.createdAt,
    this.updatedAt,
  });

  // Factory constructor to create a Post instance from JSON data
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      imageUrl: json['image_url'] as String?,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String) 
        : null,
    );
  }
}
