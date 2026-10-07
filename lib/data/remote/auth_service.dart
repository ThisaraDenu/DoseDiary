import 'dart:convert';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import '../local/database_provider.dart';
import 'supabase_sync_service.dart';

/// Thin wrapper around Supabase Auth so UI code never imports supabase_flutter directly.
class AuthService {
  AuthService._();

  static SupabaseClient? get _clientSafe {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static SupabaseClient get _client => Supabase.instance.client;

  // ── State ─────────────────────────────────────────────────────────────────

  static User? get currentUser {
    try {
      return _clientSafe?.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  static Session? get currentSession {
    try {
      return _clientSafe?.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  static bool get isLoggedIn => currentUser != null;

  static bool get isGoogleUser {
    final metadata = currentUser?.appMetadata;
    if (metadata == null) return false;
    if (metadata['provider'] == 'google') return true;
    final providers = metadata['providers'];
    return providers is List && providers.contains('google');
  }

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
        await ensurePublicId();
      }
    });
  }

  // ── Sign Up ───────────────────────────────────────────────────────────────

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
    String? dateOfBirth,
    String? gender,
    String? phoneNumber,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {
        if (fullName != null) 'full_name': fullName,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
        if (gender != null) 'gender': gender,
        if (phoneNumber != null) 'phone_number': phoneNumber,
      },
    );

    // Create profile row and initialize clean storage if user was created successfully
    if (response.user != null) {
      await _upsertProfile(
        response.user!,
        fullName: fullName,
        dateOfBirth: dateOfBirth,
        gender: gender,
        phoneNumber: phoneNumber,
      );
      await ensurePublicId();
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
      email: email.trim().toLowerCase(),
      password: password,
    );
    if (response.user != null) {
      await ensurePublicId();
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
        await ensurePublicId();
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

  // ── Email Verification ────────────────────────────────────────────────────

  /// Resends the signup confirmation OTP through Supabase Auth.
  /// Email delivery is handled by the SMTP provider configured in Supabase.
  static Future<void> resendSignupCode(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email.trim().toLowerCase(),
    );
  }

  /// Validates the signup OTP that Supabase sent to the user's email.
  static Future<bool> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = code.trim();

    try {
      final response = await _client.auth.verifyOTP(
        email: cleanEmail,
        token: cleanCode,
        type: OtpType.signup,
      );
      return response.user != null || response.session != null;
    } on AuthException {
      return false;
    }
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
      final client = _clientSafe;
      if (client != null) {
        final data = await client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (data != null) {
          try {
            final db = await AppDatabase.instance.database;
            await db.insert(
                'profiles',
                {
                  'id': data['id'],
                  'full_name': data['full_name'] ?? '',
                  'avatar_url': data['avatar_url'],
                  'date_of_birth': data['date_of_birth'],
                  'gender': data['gender'],
                  'phone_number': data['phone_number'],
                  'public_id': data['public_id'],
                  'preferred_language': data['preferred_language'] ?? 'en',
                  'text_scale_factor': data['text_scale_factor'] ?? 1.0,
                  'simple_wording': data['simple_wording'] == true ? 1 : 0,
                  'notification_sound':
                      data['notification_sound'] == false ? 0 : 1,
                  'notification_vibration':
                      data['notification_vibration'] == false ? 0 : 1,
                  'privacy_safe_previews':
                      data['privacy_safe_previews'] == false ? 0 : 1,
                  'created_at': data['created_at']?.toString() ??
                      DateTime.now().toIso8601String(),
                  'updated_at': data['updated_at']?.toString() ??
                      DateTime.now().toIso8601String(),
                },
                conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (_) {}
          return _withAuthMetadataFallback(user, data);
        }
      }
    } catch (_) {}

    try {
      final db = await AppDatabase.instance.database;
      final results = await db.query(
        'profiles',
        where: 'id = ?',
        whereArgs: [user.id],
        limit: 1,
      );
      if (results.isNotEmpty) {
        return _withAuthMetadataFallback(user, results.first);
      }
    } catch (_) {}

    final metadataProfile = _withAuthMetadataFallback(user, const {});
    return metadataProfile.length > 2 ? metadataProfile : null;
  }

  static Future<bool> needsProfileCompletion() async {
    final metadata = currentUser?.userMetadata;
    if (metadata?['profile_completed'] == true) return false;

    final profile = await getProfile();
    return !_hasRequiredProfileFields(profile);
  }

  /// Returns the signed-in user's stable public ID (for example #04217).
  /// Supabase allocates it under a unique database constraint, so two users
  /// can never receive the same ID.
  static Future<String?> ensurePublicId() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final result = await _client.rpc('ensure_public_id');
      final publicId = result?.toString().trim();
      if (publicId == null || publicId.isEmpty) return null;

      try {
        final db = await AppDatabase.instance.database;
        await db.update(
          'profiles',
          {'public_id': publicId},
          where: 'id = ?',
          whereArgs: [user.id],
        );
      } catch (_) {}
      return publicId;
    } catch (_) {
      try {
        final data = await _client
            .from('profiles')
            .select('public_id')
            .eq('id', user.id)
            .maybeSingle();
        return data?['public_id']?.toString();
      } catch (_) {
        return null;
      }
    }
  }

  static Future<void> updateProfile(Map<String, dynamic> updates) async {
    final user = currentUser;
    if (user == null) return;
    final nowIso = DateTime.now().toIso8601String();
    final cloudUpdates = Map<String, dynamic>.from(updates);
    cloudUpdates['updated_at'] = nowIso;

    try {
      final client = _clientSafe;
      if (client != null) {
        await client.from('profiles').update(cloudUpdates).eq('id', user.id);
      }
    } catch (_) {}

    try {
      final db = await AppDatabase.instance.database;
      final localUpdates = Map<String, dynamic>.from(updates);
      localUpdates['updated_at'] = nowIso;
      await db.update(
        'profiles',
        localUpdates,
        where: 'id = ?',
        whereArgs: [user.id],
      );
    } catch (_) {}
  }

  /// Saves the required onboarding fields to Supabase and verifies that the
  /// profile row was updated before allowing profile completion to continue.
  static Future<void> saveCompletedProfile(
    Map<String, dynamic> updates,
  ) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('No signed-in user.');
    }

    final nowIso = DateTime.now().toIso8601String();

    // Persist completion on the Supabase user as well as the profile row. The
    // marker remains available when a legacy project lacks newer columns.
    await _client.auth.updateUser(
      UserAttributes(
        data: {
          ...updates,
          'profile_completed': true,
          'profile_completed_at': nowIso,
        },
      ),
    );

    // Upsert so a missing profile row cannot block the first Google login.
    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        ...updates,
        'updated_at': nowIso,
      }, onConflict: 'id');
    } catch (_) {}

    // Keep the completed details available to offline/local profile reads.
    try {
      final db = await AppDatabase.instance.database;
      final changed = await db.update(
        'profiles',
        {...updates, 'updated_at': nowIso},
        where: 'id = ?',
        whereArgs: [user.id],
      );
      if (changed == 0) {
        await db.insert('profiles', {
          'id': user.id,
          ...updates,
          'preferred_language': 'en',
          'text_scale_factor': 1.0,
          'simple_wording': 0,
          'notification_sound': 1,
          'notification_vibration': 1,
          'privacy_safe_previews': 1,
          'created_at': nowIso,
          'updated_at': nowIso,
        });
      }
    } catch (_) {}
  }

  /// Uploads user profile photo to Supabase Storage bucket 'avatars'
  /// and updates the 'avatar_url' column in the 'profiles' table.
  /// If the Storage bucket is not yet configured, automatically falls back
  /// to an encoded Data URI so the image is safely saved in Supabase database.
  static Future<String?> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final user = currentUser;
    if (user == null) return null;

    final ext = fileExtension.replaceAll('.', '').toLowerCase();
    final fileName =
        '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    String? avatarUrl;

    // 1. Try uploading to Supabase Storage 'avatars' bucket
    try {
      final client = _clientSafe;
      if (client != null) {
        await client.storage.from('avatars').uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(
                contentType: 'image/$ext',
                upsert: true,
              ),
            );
        avatarUrl = client.storage.from('avatars').getPublicUrl(fileName);
      }
    } catch (_) {
      // 2. Fallback to data URI if bucket doesn't exist or isn't accessible
      final base64Str = base64Encode(bytes);
      avatarUrl = 'data:image/$ext;base64,$base64Str';
    }

    // 3. Update Supabase 'profiles' table and local SQLite cache
    await updateProfile({'avatar_url': avatarUrl});

    return avatarUrl;
  }

  // ── Private Helpers ───────────────────────────────────────────────────────

  static bool _hasRequiredProfileFields(Map<String, dynamic>? profile) {
    if (profile == null) return false;

    bool isPresent(String key) {
      final value = profile[key];
      return value != null && value.toString().trim().isNotEmpty;
    }

    return isPresent('full_name') &&
        isPresent('date_of_birth') &&
        isPresent('gender') &&
        isPresent('phone_number');
  }

  static Map<String, dynamic> _withAuthMetadataFallback(
    User user,
    Map<String, dynamic> profile,
  ) {
    final merged = Map<String, dynamic>.from(profile);
    final metadata = user.userMetadata ?? const <String, dynamic>{};

    for (final key in const [
      'full_name',
      'date_of_birth',
      'gender',
      'phone_number',
    ]) {
      final current = merged[key]?.toString().trim();
      if (current == null || current.isEmpty) {
        final fallback = metadata[key];
        if (fallback != null && fallback.toString().trim().isNotEmpty) {
          merged[key] = fallback;
        }
      }
    }

    merged['id'] ??= user.id;
    merged['email'] ??= user.email;
    return merged;
  }

  /// Computes integer age given an ISO date string (YYYY-MM-DD). Returns null if invalid.
  static int? calculateAge(String? dateOfBirthStr) {
    if (dateOfBirthStr == null || dateOfBirthStr.trim().isEmpty) return null;
    try {
      final dob = DateTime.parse(dateOfBirthStr);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age >= 0 ? age : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _upsertProfile(
    User user, {
    String? fullName,
    String? dateOfBirth,
    String? gender,
    String? phoneNumber,
  }) async {
    try {
      final meta = user.userMetadata ?? {};
      final existing = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      String? nonEmpty(dynamic value) {
        final text = value?.toString().trim();
        return text == null || text.isEmpty ? null : text;
      }

      // Existing profile details always win during sign-in. This prevents a
      // Google auth refresh from replacing user-entered fields with nulls.
      final name = nonEmpty(existing?['full_name']) ??
          nonEmpty(fullName) ??
          nonEmpty(meta['full_name']) ??
          user.email?.split('@').first ??
          '';
      final dob = nonEmpty(existing?['date_of_birth']) ??
          nonEmpty(dateOfBirth) ??
          nonEmpty(meta['date_of_birth']);
      final gen = nonEmpty(existing?['gender']) ??
          nonEmpty(gender) ??
          nonEmpty(meta['gender']);
      final phone = nonEmpty(existing?['phone_number']) ??
          nonEmpty(phoneNumber) ??
          nonEmpty(meta['phone_number']);
      final now = DateTime.now().toIso8601String();

      final profileMap = <String, dynamic>{
        'id': user.id,
        'full_name': name,
        if (existing?['avatar_url'] != null)
          'avatar_url': existing?['avatar_url'],
        if (existing?['public_id'] != null) 'public_id': existing?['public_id'],
        if (dob != null) 'date_of_birth': dob,
        if (gen != null) 'gender': gen,
        if (phone != null) 'phone_number': phone,
        'preferred_language': existing?['preferred_language'] ?? 'en',
        'text_scale_factor': existing?['text_scale_factor'] ?? 1.0,
        'simple_wording': existing?['simple_wording'] ?? false,
        'notification_sound': existing?['notification_sound'] ?? true,
        'notification_vibration': existing?['notification_vibration'] ?? true,
        'privacy_safe_previews': existing?['privacy_safe_previews'] ?? true,
        'created_at': existing?['created_at'] ?? now,
        'updated_at': now,
      };

      await _client.from('profiles').upsert(profileMap, onConflict: 'id');

      try {
        final db = await AppDatabase.instance.database;
        await db.insert(
            'profiles',
            {
              'id': user.id,
              'full_name': name,
              'avatar_url': existing?['avatar_url'],
              'date_of_birth': dob,
              'gender': gen,
              'phone_number': phone,
              'public_id': existing?['public_id'],
              'preferred_language': existing?['preferred_language'] ?? 'en',
              'text_scale_factor': existing?['text_scale_factor'] ?? 1.0,
              'simple_wording': existing?['simple_wording'] == true ? 1 : 0,
              'notification_sound':
                  existing?['notification_sound'] == false ? 0 : 1,
              'notification_vibration':
                  existing?['notification_vibration'] == false ? 0 : 1,
              'privacy_safe_previews':
                  existing?['privacy_safe_previews'] == false ? 0 : 1,
              'created_at': existing?['created_at']?.toString() ?? now,
              'updated_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}
    } catch (_) {
      // Silently ignore if profiles table is not yet migrated in Supabase
    }
  }
}
