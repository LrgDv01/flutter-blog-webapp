import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';
import 'package:flutter_blog_webapp/models/post.dart';

// StateNotifier to manage posts state and actions
class PostsNotifier extends StateNotifier<List<Post>> {
  PostsNotifier() : super([]) {
    fetchPosts(); // Load posts on initialization
  }

  // Fetch all posts from Supabase, ordered by creation date
  Future<void> fetchPosts() async {
    final response = await supabase
        .from('posts')
        .select()
        .order('created_at', ascending: false);

    // Convert response to List<Post> and update state
    state = response.map<Post>((json) => Post.fromJson(json)).toList();
  }

  // Add a new post to the database
  Future<void> createPost({
    required String title,
    required String content,
    String? imageUrl,
  }) async {
    // Check if user is authenticated
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Insert post with user ID
    await supabase.from('posts').insert({
      'title': title,
      'content': content,
      'user_id': user.id,
      'image_url': imageUrl,
    });

    // Refresh posts list
    await fetchPosts();
  }

  // Remove a post by ID
  Future<void> deletePost(String postId) async {
    await supabase.from('posts').delete().eq('id', postId);
    await fetchPosts(); // Refresh list after deletion
  }
}

// Riverpod provider for posts management
final postsProvider = StateNotifierProvider<PostsNotifier, List<Post>>(
  (ref) => PostsNotifier(),
);
