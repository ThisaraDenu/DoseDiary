import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import '../local/database_provider.dart';
import 'supabase_sync_service.dart';

/// Thin wrapper around Supabase Auth so UI code never imports supabase_flutter directly.
class AuthService {
  AuthService._();

  static SupabaseClient get _client => Supabase.instance.client;

  // ── State ─────────────────────────────────────────────────────────────────

  static User? get currentUser => _client.auth.currentUser;
  static Session? get currentSession => _client.auth.currentSession;
  static bool get isLoggedIn => currentUser != null;

  /// Stream of auth state changes (sign-in, sign-out, token refresh).
  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  /// Initializes auth event listeners (e.g. auto-creating profiles on OAuth sign in).
  static void init() {
    _client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        final user = data.session!.user;
        final name = user.userMetadata?['full_name'] as String?;
        await _upsertProfile(user, fullName: name);
      }
    });
  }

  // ── Sign Up ───────────────────────────────────────────────────────────────

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );

    // Create profile row and initialize clean storage if user was created successfully
    if (response.user != null) {
      await _upsertProfile(response.user!, fullName: fullName);
      try {
        await AppDatabase.instance.clearAllUserData();
        await SupabaseSyncService.pullFromCloud();
      } catch (_) {}
    }
    return response;
  }

  // ── Sign In ───────────────────────────────────────────────────────────────

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user != null) {
      try {
        await AppDatabase.instance.clearAllUserData();
        await SupabaseSyncService.pullFromCloud();
      } catch (_) {}
    }
    return response;
  }

  // ── Google Sign In ────────────────────────────────────────────────────────

  /// Performs Google Sign-In.
  /// If [SupabaseConfig.googleWebClientId] is set, uses native Google Sign-In
  /// with ID Token verification. Otherwise, falls back to Supabase browser OAuth.
  static Future<AuthResponse?> signInWithGoogle() async {
    if (SupabaseConfig.googleWebClientId.isNotEmpty) {
      // 1. Native Google Sign-In via google_sign_in package
      final googleSignIn = GoogleSignIn(
        serverClientId: SupabaseConfig.googleWebClientId,
        clientId: SupabaseConfig.googleIosClientId.isNotEmpty
            ? SupabaseConfig.googleIosClientId
            : null,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in modal
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw 'No ID token returned by Google Sign-In.';
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        final name = response.user!.userMetadata?['full_name'] as String? ??
            googleUser.displayName;
        await _upsertProfile(response.user!, fullName: name);
        try {
          await AppDatabase.instance.clearAllUserData();
          await SupabaseSyncService.pullFromCloud();
        } catch (_) {}
      }
      return response;
    } else {
      // 2. Web browser OAuth redirect fallback
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: SupabaseConfig.redirectUrl,
      );
      return null;
    }
  }

  // ── Password Reset ────────────────────────────────────────────────────────

  static Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  static Future<void> signOut() async {
    try {
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (_) {}
    try {
      await AppDatabase.instance.clearAllUserData();
    } catch (_) {}
    await _client.auth.signOut();
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      return data;
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateProfile(Map<String, dynamic> updates) async {
    final user = currentUser;
    if (user == null) return;
    try {
      await _client.from('profiles').update(updates).eq('id', user.id);
    } catch (_) {}
  }

  // ── Private Helpers ───────────────────────────────────────────────────────

  static Future<void> _upsertProfile(User user, {String? fullName}) async {
    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        'full_name': fullName ??
            user.userMetadata?['full_name'] ??
            user.email?.split('@').first ??
            '',
        'preferred_language': 'en',
        'text_scale_factor': 1.0,
        'simple_wording': false,
        'notification_sound': true,
        'notification_vibration': true,
        'privacy_safe_previews': true,
      }, onConflict: 'id');
    } catch (_) {
      // Silently ignore if profiles table is not yet migrated in Supabase
    }
  }
}
