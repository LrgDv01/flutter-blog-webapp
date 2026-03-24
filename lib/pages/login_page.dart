import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blog_webapp/providers/auth_provider.dart';
import 'package:flutter_blog_webapp/utils/error_utils.dart';
import 'package:flutter_blog_webapp/widgets/inline_error_banner.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  // Form and text controllers
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _submitError;

  void _clearSubmitError() {
    if (_submitError == null) return;
    setState(() => _submitError = null);
  }

  @override
  void dispose() {
    // Cleanup resources
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Handle login logic
  Future<void> _login() async {
    // Validate form before proceeding
    if (!_formKey.currentState!.validate()) return;
    if (_submitError != null) {
      setState(() => _submitError = null);
    }

    try {
      // Sign in user via auth provider
      await ref
          .read(authProvider.notifier)
          .signIn(_emailController.text.trim(), _passwordController.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitError = formatAppError(
            e,
            fallbackMessage: 'Failed to sign in. Please try again.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state for loading
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header section
                const Icon(
                  Icons.article_outlined,
                  size: 100,
                  color: Colors.indigo,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Welcome !',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Text('Sign in to continue to your blog'),
                const SizedBox(height: 32),

                // Email field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => _clearSubmitError(),
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 16),

                // Password field with visibility toggle
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    // Toggle visibility button
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  onChanged: (_) => _clearSubmitError(),
                  validator: (value) => value == null || value.length < 6
                      ? 'Password too short'
                      : null,
                ),
                const SizedBox(height: 24),

                if (_submitError != null) ...[
                  const SizedBox(height: 16),
                  InlineErrorBanner(message: _submitError!),
                  const SizedBox(height: 16),
                ],

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _login,
                    child: authState.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Login', style: TextStyle(fontSize: 18)),
                  ),
                ),

                // Register link
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Don\'t have an account? Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
