import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blog_webapp/models/comment.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';
import 'package:flutter_blog_webapp/utils/error_utils.dart';

// Keep Supabase row parsing in one place.
List<Comment> _parseComments(List<dynamic> response) {
  return response
      .map((json) => Comment.fromJson(Map<String, dynamic>.from(json)))
      .toList();
}

// Reuse one auth guard across comment write operations.
String _requireUserId(String action) {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    throw Exception('You must be logged in to $action.');
  }

  return userId;
}

// State for the comments thread on the post detail page.
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
    // `clearError` removes stale errors after a successful retry.
    return CommentsState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// State management for comments on the post detail page.
class CommentsNotifier extends StateNotifier<CommentsState> {
  final String postId;

  CommentsNotifier(this.postId) : super(const CommentsState()) {
    fetchComments();
  }

  void _setLoading() {
    state = state.copyWith(isLoading: true, clearError: true); // Reset stale errors when starting a new request.
  }

  void _setError(
    Object error, {
    String fallbackMessage = 'Failed to load comments.',
  }) {
    state = state.copyWith(
      isLoading: false,
      error: formatAppError(error, fallbackMessage: fallbackMessage),
    );
  }

  void _replaceComment(Comment updatedComment) {
    // Update the edited row in place instead of fetching the whole thread again.
    state = state.copyWith(
      comments: [
        for (final comment in state.comments)
          if (comment.id == updatedComment.id) updatedComment else comment,
      ],
      isLoading: false,
      clearError: true,
    );
  }

  // Fetch all comments for the post, ordered by creation time with newest first.
  Future<void> fetchComments() async {
    _setLoading();
    try {
      final response = await supabase
          .from('comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: false);

      state = state.copyWith(
        comments: _parseComments(response),
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      _setError(e, fallbackMessage: 'Failed to load comments.');
    }
  }

  // Creates a new comment with the current user's ID. RLS rules will prevent unauthorized inserts.
  Future<void> addComment({
    required String content,
    String? imageUrl,
    bool isAnonymous = false,
  }) async {
    _setLoading();
    try {
      final userId = _requireUserId('comment');
      await supabase.from('comments').insert({
        'post_id': postId,
        'user_id': userId,
        'content': content,
        'image_url': imageUrl,
        'is_anonymous': isAnonymous,
      });
      await fetchComments();
    } catch (e) {
      _setError(e, fallbackMessage: 'Failed to add comment.');
      rethrow;
    }
  }

  // Deletes the comment if it belongs to the current user. RLS rules will prevent unauthorized deletions.
  Future<void> deleteComment(String commentId) async {
    _setLoading();
    try {
      await supabase.from('comments').delete().eq('id', commentId);
      await fetchComments();
    } catch (e) {
      _setError(e, fallbackMessage: 'Failed to delete comment.');
      rethrow;
    }
  }

  // Updates are done in-place, so we don't have to worry about list ordering changes.
  Future<void> updateComment({
    required String commentId,
    required String content,
    String? imageUrl,
    bool updateImage = false,
    bool? isAnonymous,
  }) async {
    _setLoading();
    try {
      final payload = {
        'content': content,
        'updated_at': DateTime.now().toIso8601String(),
        // Only send image changes when the user actually changed that field.
        if (updateImage) 'image_url': imageUrl,
        if (isAnonymous != null) 'is_anonymous': isAnonymous,
      };

      final updatedRows = await supabase
          .from('comments')
          .update(payload)
          .eq('id', commentId)
          .select();

      if (updatedRows.isEmpty) {
        throw Exception(
          'Failed to update comment. Comment may have been deleted.',
        );
      }

      // Update the edited row in place instead of fetching the whole thread again.
      final updatedComment = Comment.fromJson(
        Map<String, dynamic>.from(updatedRows.first),
      );
      _replaceComment(updatedComment); 
    } catch (e) {
      _setError(e, fallbackMessage: 'Failed to update comment.');
      rethrow;
    }
  }
}

final commentsProviderFamily =
    StateNotifierProvider.family<CommentsNotifier, CommentsState, String>(
      // Create one comments state per post detail page.
      (ref, postId) => CommentsNotifier(postId),
    );
