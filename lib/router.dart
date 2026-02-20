import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blog_webapp/providers/auth_provider.dart';
import 'package:flutter_blog_webapp/pages/login_page.dart';
import 'package:flutter_blog_webapp/pages/register_page.dart';
import 'package:flutter_blog_webapp/pages/home_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;

      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';

      // If not logged in - force to login (except on register page)
      if (!isLoggedIn && !isLoggingIn && !isRegistering) {
        return '/login';
      }

      // If logged in - never show login/register
      if (isLoggedIn && (isLoggingIn || isRegistering)) {
        return '/';
      }

      return null; // no redirect
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});