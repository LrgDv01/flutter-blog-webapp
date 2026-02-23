import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Initialize Supabase with environment variables
Future<void> initSupabase() async {
  // Load environment variables from .env file
  await dotenv.load(fileName: "assets/.env");

  // Initialize Supabase with URL and anonymous key
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    debug: true,
  );
}

// Create a global Supabase client instance
final supabase = Supabase.instance.client;
