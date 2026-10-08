 //  +  DoseDiary App Entry Point
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'app.dart';
import 'core/supabase_config.dart';
import 'services/notification_service.dart';
import 'data/local/database_provider.dart';
import 'data/remote/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    tz.initializeTimeZones();

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      debug: false,
    );
    AuthService.init();

    await NotificationService.initialize();

    await DatabaseProvider.initialize();

    final prefs = await SharedPreferences.getInstance();

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const DoseDiaryApp(),
      ),
    );
  } catch (e, st) {
    debugPrint('DoseDiary startup error: $e\n$st');
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences not initialized'),
);
