import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blog_webapp/supabase_client.dart';
import 'package:flutter_blog_webapp/router.dart';

void main() async {
  // Initialize Flutter bindings before running async code
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Supabase client
  await initSupabase();

  // Wrap the app with ProviderScope to enable Riverpod state management
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// Main application widget
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch router provider for navigation configuration
    final router = ref.watch(routerProvider);

    // Configure MaterialApp with routing and theme
    return MaterialApp.router(
      title: 'Flutter Blog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Use indigo as primary color with Material 3 design
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      // Enable router-based navigation
      routerConfig: router,
    );
  }
}