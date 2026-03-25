import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrlFromDefine = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKeyFromDefine = String.fromEnvironment('SUPABASE_ANON_KEY');

// Initialize Supabase with environment variables
Future<void> initSupabase() async {
  var url = _supabaseUrlFromDefine;
  var anonKey = _supabaseAnonKeyFromDefine;

  // Fall back to the local .env file during development when dart-defines are absent.
  if (url.isEmpty || anonKey.isEmpty) {
    await dotenv.load(fileName: 'assets/.env');
    url = dotenv.env['SUPABASE_URL'] ?? url;
    anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? anonKey;
  }

  if (url.isEmpty || anonKey.isEmpty) {
    throw Exception(
      'Missing Supabase configuration. Provide SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define or assets/.env.',
    );
  }

  // Initialize Supabase with URL and anonymous key
  await Supabase.initialize(
    url: url,
    anonKey: anonKey,
    debug: true,
  );
}

// Create a global Supabase client instance
final supabase = Supabase.instance.client;
