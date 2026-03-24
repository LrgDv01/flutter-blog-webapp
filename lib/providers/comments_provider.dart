import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blog_webapp/models/comment.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';
import 'package:flutter_blog_webapp/utils/error_utils.dart';

List<Comment> _parseComments(List<dynamic> response) {
  return response
      .map((json) => Comment.fromJson(Map<String, dynamic>.from(json)))
      .toList();
}

String _requireUserId(String action) {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    throw Exception('You must be logged in to $action.');
  }

  return userId;
}

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
    return CommentsState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CommentsNotifier extends StateNotifier<CommentsState> {
  final String postId;

  CommentsNotifier(this.postId) : super(const CommentsState()) {
    fetchComments();
  }

  void _setLoading() {
    state = state.copyWith(isLoading: true, clearError: true);
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
    state = state.copyWith(
      comments: [
        for (final comment in state.comments)
          if (comment.id == updatedComment.id) updatedComment else comment,
      ],
      isLoading: false,
      clearError: true,
    );
  }

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
      (ref, postId) => CommentsNotifier(postId),
    );
