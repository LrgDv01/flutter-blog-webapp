class Comment {
  // Fields representing the properties of a comment
  final String id;
  final String postId;
  final String userId;
  final String content;
  final String? imageUrl;
  final String? authorName; 
  final DateTime createdAt;
  final DateTime? updatedAt;
  

  // Constructor to initialize all fields of the Comment class
  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    this.imageUrl,
    this.authorName,
    required this.createdAt,
    this.updatedAt,
  });

  // Factory constructor to create a Comment instance from JSON data
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      imageUrl: json['image_url'] as String?,
      authorName: json['author_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
        ? DateTime.parse(json['updated_at'] as String) 
        : null,
    );
  }
}
