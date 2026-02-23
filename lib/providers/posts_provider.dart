import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';
import 'package:flutter_blog_webapp/models/post.dart';

// StateNotifier to manage posts state and actions
class PostsNotifier extends StateNotifier<List<Post>> {
  PostsNotifier() : super([]) {
    fetchPosts();
  }

  // Method to fetch posts from Supabase
  Future<void> fetchPosts() async {
    final response = await supabase
        .from('posts')
        .select()
        .order('created_at', ascending: false);

    state = response.map<Post>((json) => Post.fromJson(json)).toList(); // Update state with fetched posts
  }

  // Method to create a new post
  Future<void> createPost({
    required String title,
    required String content,
    required List<String> imageUrls,
  }) async {
    final user = supabase.auth.currentUser; // Ensure user is logged in before creating a post
    if (user == null) return;

    await supabase.from('posts').insert({
      'title': title,
      'content': content,
      'user_id': user.id,
      'images': imageUrls,
    });

    await fetchPosts(); // refresh list
  }

  // Additional methods for updating and deleting posts can be added here
  Future<void> deletePost(String postId) async {
    await supabase.from('posts').delete().eq('id', postId);
    await fetchPosts();
  }
}

// Provider to access posts state and actions
final postsProvider = StateNotifierProvider<PostsNotifier, List<Post>>(
  (ref) => PostsNotifier(),
);