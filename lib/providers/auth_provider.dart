import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';

const _userNotSet = Object();

// State class to hold authentication information
class AuthState {
  final User? user;
  final bool isLoading;

  AuthState({this.user, this.isLoading = false});

  // Check if user is authenticated
  bool get isAuthenticated => user != null;

  // Create a copy with optional updates
  AuthState copyWith({Object? user = _userNotSet, bool? isLoading}) {
    return AuthState(
      user: identical(user, _userNotSet) ? this.user : user as User?,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// StateNotifier to manage authentication state and actions
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    _listenToAuthChanges();
    _getCurrentSession();
  }

  // Listen to real-time auth state changes from Supabase
  void _listenToAuthChanges() {
    supabase.auth.onAuthStateChange.listen((data) {
      state = state.copyWith(user: data.session?.user);
    });
  }

  // Load current session on init
  Future<void> _getCurrentSession() async {
    final session = supabase.auth.currentSession;
    state = state.copyWith(user: session?.user);
  }

  // Sign in with email and password
  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null || response.session == null) {
        throw AuthException('Invalid email or password.');
      }

      state = state.copyWith(user: response.user);
    } catch (e) {
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // Register new user with email, password, and display name
  Future<void> signUp(String email, String password, String displayName) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
      state = state.copyWith(user: response.session?.user);
    } catch (e) {
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // Sign out the current user
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await supabase.auth.signOut();
      state = state.copyWith(user: null);
    } catch (e) {
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

// Riverpod provider for authentication
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
