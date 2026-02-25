import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';
import 'package:flutter_blog_webapp/models/post.dart';
import 'package:flutter_blog_webapp/models/comment.dart';

/// Manages the state of all blog posts
class PostsNotifier extends StateNotifier<List<Post>> {
  PostsNotifier() : super([]) {
    fetchPosts();
  }

  /// Fetches all posts from the database
  Future<void> fetchPosts() async {
    final response = await supabase
        .from('posts')
        .select()
        .order('created_at', ascending: false);

    state = response.map<Post>((json) => Post.fromJson(json)).toList();
  }

  /// Creates a new post and refreshes the list
  Future<void> createPost({
    required String title,
    required String content,
    String? imageUrl,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('posts').insert({
      'title': title,
      'content': content,
      'user_id': user.id,
      'image_url': imageUrl,
    });
    await fetchPosts();
  }

  /// Updates an existing post and refreshes the list
  Future<void> updatePost({
    required String postId,
    required String title,
    required String content,
    String? imageUrl,
  }) async {
    await supabase
        .from('posts')
        .update({'title': title, 'content': content, 'image_url': ?imageUrl}) // Handle null imageUrl properly
        .eq('id', postId);
    await fetchPosts();
  }

  /// Deletes a post and refreshes the list
  Future<void> deletePost(String postId) async {
    await supabase.from('posts').delete().eq('id', postId);
    await fetchPosts();
  }
}

/// Global provider for posts
final postsProvider = StateNotifierProvider<PostsNotifier, List<Post>>(
  (ref) => PostsNotifier(),
);

/// Manages comments for a specific post
class CommentsNotifier extends StateNotifier<List<Comment>> {
  final String postId;
  CommentsNotifier(this.postId) : super([]) {
    fetchComments();
  }

  /// Fetches all comments for this post
  Future<void> fetchComments() async {
    final response = await supabase
        .from('comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    state = response.map<Comment>((json) => Comment.fromJson(json)).toList();
  }

  /// Adds a new comment to the post
  Future<void> addComment({required String content, String? imageUrl}) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('comments').insert({
      'post_id': postId,
      'user_id': user.id,
      'content': content,
      'image_url': imageUrl,
    });
    await fetchComments();
  }

  /// Deletes a comment and refreshes the list
  Future<void> deleteComment(String commentId) async {
    await supabase.from('comments').delete().eq('id', commentId);
    await fetchComments();
  }
}

/// Family provider for comments - creates separate notifier per post
final commentsProviderFamily =
    StateNotifierProvider.family<CommentsNotifier, List<Comment>, String>(
      (ref, postId) => CommentsNotifier(postId),
    );
