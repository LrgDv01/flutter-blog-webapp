import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String formatAppError(
  Object error, {
  String fallbackMessage = 'Something went wrong. Please try again.',
}) {
  if (error is AuthException) {
    final message = error.message.trim();
    final normalized = message.toLowerCase();

    if (normalized.contains('invalid login credentials')) {
      return 'Invalid email or password.';
    }

    if (normalized.contains('user already registered')) {
      return 'An account with this email already exists.';
    }

    if (normalized.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }

    return message.isEmpty ? fallbackMessage : message;
  }

  if (error is PostgrestException) {
    final message = error.message.trim();
    return message.isEmpty ? fallbackMessage : message;
  }

  if (error is StorageException) {
    final message = error.message.trim();
    return message.isEmpty ? fallbackMessage : message;
  }

  final cleaned = error
      .toString()
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .trim();

  if (cleaned.isEmpty || cleaned == 'null') {
    return fallbackMessage;
  }

  return cleaned;
}

void showErrorSnackBar(
  BuildContext context,
  Object error, {
  String fallbackMessage = 'Something went wrong. Please try again.',
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        formatAppError(error, fallbackMessage: fallbackMessage),
      ),
    ),
  );
}
