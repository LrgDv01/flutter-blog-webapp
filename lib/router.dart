import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blog_webapp/providers/auth_provider.dart';
import 'package:flutter_blog_webapp/pages/login_page.dart';
import 'package:flutter_blog_webapp/pages/register_page.dart';
import 'package:flutter_blog_webapp/pages/create_post_page.dart';
import 'package:flutter_blog_webapp/pages/home_page.dart';

// Provides a GoRouter instance with authentication-based routing
final routerProvider = Provider<GoRouter>((ref) {
  // Watch auth state to determine user authentication status
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login', // Start at login page
    debugLogDiagnostics: true, // Enable debug logging
    // Handle navigation redirects based on auth state
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;

      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';

      // Redirect to login if not authenticated and not on auth pages
      if (!isLoggedIn && !isLoggingIn && !isRegistering) {
        return '/login';
      }

      // Redirect to home if authenticated but on auth pages
      if (isLoggedIn && (isLoggingIn || isRegistering)) {
        return '/home';
      }

      // No redirect needed
      return null;
    },
    // Define app routes
    routes: [
      GoRoute(
        path: '/create-post',
        builder: (context, state) => const CreatePostPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
    ],
  );
});
