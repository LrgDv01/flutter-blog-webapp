import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blog_webapp/models/comment.dart';
import 'package:flutter_blog_webapp/models/post.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';

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

// State for comments tied to a single post.
class CommentsState {
  final List<Comment> comments;
  final bool isLoading;
  final String? error;

  const CommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.error,
  });

  CommentsState copyWith({
    List<Comment>? comments,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    // Same error reset behavior as PostsState.
    return CommentsState(
      comments: comments ?? this.comments,
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

  // Used by initial load and pull-to-refresh.
  Future<void> fetchPosts() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await supabase
          .from('posts')
          .select()
          .order('created_at', ascending: false);

      // print('Post ITO : $response');
      
      state = state.copyWith(
        posts: (response as List)
            .map((json) => Post.fromJson(Map<String, dynamic>.from(json)))
            .toList(),
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Creates a new post and refreshes the list
  Future<void> createPost({
    required String title,
    required String content,
    String? imageUrl,
    bool isAnonymous = false,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to create a post.');
      }

      await supabase.from('posts').insert({
        'title': title,
        'content': content,
        'user_id': user.id,
        'image_url': imageUrl,
        'is_anonymous': isAnonymous,
      });
      await fetchPosts();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updatePost({
    required String postId,
    required String title,
    required String content,
    String? imageUrl,
    bool? isAnonymous,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
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
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await supabase.from('posts').delete().eq('id', postId);
      await fetchPosts();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

// Global feed provider used by home/detail screens.
final postsProvider = StateNotifierProvider<PostsNotifier, PostsState>(
  (ref) => PostsNotifier(),
);

class CommentsNotifier extends StateNotifier<CommentsState> {
  final String postId;
  CommentsNotifier(this.postId) : super(const CommentsState()) {
    // Load comments for this post instance immediately.
    fetchComments();
  }

  // Reload comments whenever a comment is added/removed.
  Future<void> fetchComments() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await supabase
          .from('comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      state = state.copyWith(
        comments: (response as List)
            .map((json) => Comment.fromJson(Map<String, dynamic>.from(json)))
            .toList(),
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addComment({
    required String content,
    String? imageUrl,
    bool isAnonymous = false,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to comment.');
      }

      await supabase.from('comments').insert({
        'post_id': postId,
        'user_id': user.id,
        'content': content,
        'image_url': imageUrl,
        'is_anonymous': isAnonymous,
      });
      await fetchComments();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteComment(String commentId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await supabase.from('comments').delete().eq('id', commentId);
      await fetchComments();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

// Family creates one comments stream/state per post id.
final commentsProviderFamily =
    StateNotifierProvider.family<CommentsNotifier, CommentsState, String>(
      // One comments notifier instance per post id.
      (ref, postId) => CommentsNotifier(postId),
    );
