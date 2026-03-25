import 'package:flutter/material.dart';

class InlineErrorBanner extends StatelessWidget {
  final String message;

  const InlineErrorBanner({super.key, required this.message}); // `message` is required to ensure the banner always has content to display.

  @override
  Widget build(BuildContext context) {
    // Reuse theme error colors so the banner matches the active palette.
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            // Expanded lets longer error messages wrap instead of overflowing.
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
