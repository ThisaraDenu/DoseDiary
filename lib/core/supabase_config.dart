/// DoseDiary — Supabase project configuration.
/// These values are the anon (public) credentials for your project.
/// Never commit the service-role key into source code.
library;

class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://cefezlyqxbkqmhhuqmtf.supabase.co';
  static const String publishableKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNlZmV6bHlxeGJrcW1oaHVxbXRmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwNTgzMDcsImV4cCI6MjEwNTYzNDMwN30'
      '.JqGCeSR7p3dGz9MALNrt4FM06ACyjp33YYRnnRqHED8';

  static const String powerSyncUrl =
      'https://6ab235ee02481fb31b9893e4.powersync.journeyapps.com';

  /// Google OAuth Web Client ID (from Google Cloud Console).
  /// Required for native Android Google Sign-In with Supabase signInWithIdToken.
  /// Replace with your Web Client ID from Google Cloud Console.
  static const String googleWebClientId = '305524260111-g257cold7kajffruourikmg7f5eb91b0.apps.googleusercontent.com';

  /// Optional iOS Client ID if building for iOS
  static const String googleIosClientId = '';

  /// Supabase OAuth Redirect URL for browser-based OAuth flow
  static const String redirectUrl = 'io.supabase.dosediary://login-callback/';
}
