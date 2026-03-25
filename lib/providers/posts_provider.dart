import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blog_webapp/models/post.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';
import 'package:flutter_blog_webapp/utils/error_utils.dart';

// Keep feed row parsing in one helper.
List<Post> _parsePosts(List<dynamic> response) {
  return response
      .map((json) => Post.fromJson(Map<String, dynamic>.from(json)))
      .toList();
}

// Reuse one auth guard across post write operations.
String _requireUserId(String action) {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    throw Exception('You must be logged in to $action.');
  }

  return userId;
}

// State for the main posts feed.
class PostsState {
  final List<Post> posts;
  final bool isLoading;
  final String? error;

  const PostsState({this.posts = const [], this.isLoading = false, this.error});

  PostsState copyWith({
    List<Post>? posts,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    // `clearError` lets callers reset stale errors while keeping other values.
    return PostsState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PostsNotifier extends StateNotifier<PostsState> {
  PostsNotifier() : super(const PostsState()) {
    // Warm the feed as soon as the provider is first created.
    fetchPosts();
  }

  void _setLoading() {
    // Reset stale errors when starting a new request.
    state = state.copyWith(isLoading: true, clearError: true);
  }

  void _setError(Object error, {String fallbackMessage = 'Failed to load posts.'}) {
    // Store already-formatted errors so the UI can render them directly.
    state = state.copyWith(
      isLoading: false,
      error: formatAppError(error, fallbackMessage: fallbackMessage),
    );
  }

  // Used by initial load and pull-to-refresh.
  Future<void> fetchPosts() async {
    _setLoading();
    try {
      final response = await supabase
          .from('posts')
          .select()
          .order('created_at', ascending: false);

      state = state.copyWith(
        posts: _parsePosts(response),
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      _setError(e, fallbackMessage: 'Failed to load posts.');
    }
  }

  // Creates a new post and refreshes the list
  Future<void> createPost({
    required String title,
    required String content,
    String? imageUrl,
    bool isAnonymous = false,
  }) async {
    _setLoading();
    try {
      final userId = _requireUserId('create a post');
      await supabase.from('posts').insert({
        'title': title,
        'content': content,
        'user_id': userId,
        'image_url': imageUrl,
        'is_anonymous': isAnonymous,
      });
      await fetchPosts();
    } catch (e) {
      _setError(e, fallbackMessage: 'Failed to create post.');
      rethrow;
    }
  }

  // Updates are done in-place, so we don't have to worry about list ordering changes.
  Future<void> updatePost({
    required String postId,
    required String title,
    required String content,
    String? imageUrl,
    bool? isAnonymous,
  }) async {
    _setLoading();
    try {
      final updateData = <String, dynamic>{
        'title': title,
        'content': content,
        'image_url': imageUrl,
      };
      // Skip anonymous flag update when caller does not send a new value.
      if (isAnonymous != null) {
        updateData['is_anonymous'] = isAnonymous;
      }

      await supabase.from('posts').update(updateData).eq('id', postId);
      await fetchPosts();
    } catch (e) {
      _setError(e, fallbackMessage: 'Failed to update post.');
      rethrow;
    }
  }

  // Deletes the post and all its comments in one go with RLS cascade rules.
  Future<void> deletePost(String postId) async {
    _setLoading();
    try {
      await supabase.from('posts').delete().eq('id', postId);
      await fetchPosts();
    } catch (e) {
      _setError(e, fallbackMessage: 'Failed to delete post.');
      rethrow;
    }
  }
}

// Global feed provider used by home/detail screens.
final postsProvider = StateNotifierProvider<PostsNotifier, PostsState>(
  (ref) => PostsNotifier(),
);
