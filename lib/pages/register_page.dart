import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blog_webapp/providers/auth_provider.dart';
import 'package:flutter_blog_webapp/utils/error_utils.dart';
import 'package:flutter_blog_webapp/widgets/inline_error_banner.dart';
import 'package:go_router/go_router.dart';

// ConsumerStatefulWidget to access Riverpod providers
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  // Text controllers for form inputs
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  // Toggle password visibility
  bool _obscurePassword = true;
  String? _submitError;

  void _clearSubmitError() {
    if (_submitError == null) return;
    setState(() => _submitError = null);
  }

  @override
  void dispose() {
    // Clean up controllers
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  // Register user with form validation
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitError != null) {
      setState(() => _submitError = null);
    }

    try {
      // Call sign up method from auth provider
      await ref
          .read(authProvider.notifier)
          .signUp(
            _emailController.text.trim(),
            _passwordController.text,
            _displayNameController.text.trim(),
          );
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful!'),
          ),
        );
        // Navigate to login page
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitError = formatAppError(
            e,
            fallbackMessage: 'Failed to create your account. Please try again.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state for loading status
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Display name field
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _clearSubmitError(),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a display name'
                      : null,
                ),
                const SizedBox(height: 16),

                // Email field with email validation
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
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
                      ? 'Minimum 6 characters'
                      : null,
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirm your password';
                    }

                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 24),

                if (_submitError != null) ...[
                  const SizedBox(height: 16),
                  InlineErrorBanner(message: _submitError!),
                  const SizedBox(height: 16),
                ],

                // Register button with loading state
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _register,
                    child: authState.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Create Account',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ),

                const SizedBox(height: 16),
                // Link to login page
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
