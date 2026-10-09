import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/router/route_names.dart';
import 'core/services/permission_service.dart';
import 'core/theme/app_theme.dart';
import 'data/remote/auth_service.dart';
import 'l10n/app_localizations.dart';
import 'features/settings/settings_providers.dart';
import 'services/notification_service.dart';

class DoseDiaryApp extends ConsumerStatefulWidget {
  const DoseDiaryApp({super.key});

  @override
  ConsumerState<DoseDiaryApp> createState() => _DoseDiaryAppState();
}

class _DoseDiaryAppState extends ConsumerState<DoseDiaryApp> {
  StreamSubscription<NotificationLaunch>? _notificationSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _notificationSubscription =
        NotificationService.launches.listen(_openNotification);
    _authSubscription = AuthService.authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedIn &&
          state.session != null &&
          AuthService.consumeGoogleOAuthRedirect()) {
        _finishGoogleOAuthSignIn();
      }
    });
    final initialLaunch = NotificationService.takeInitialLaunch();
    if (initialLaunch != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openNotification(initialLaunch),
      );
    }
  }

  Future<void> _finishGoogleOAuthSignIn() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('onboarding_complete', true);
    if (!mounted) return;

    final router = ref.read(appRouterProvider);
    if (await AuthService.needsProfileCompletion()) {
      router.go(RouteNames.completeGoogleProfile);
    } else if (!PermissionService.hasPrompted(preferences)) {
      router.go(RouteNames.permissions);
    } else {
      router.go(RouteNames.home);
    }
  }

  void _openNotification(NotificationLaunch launch) {
    if (!mounted || !launch.payload.startsWith('dose:')) return;
    final occurrenceId = launch.payload.substring('dose:'.length);
    if (occurrenceId.isEmpty) return;
    final action = launch.actionId;
    final query = action == null || action.isEmpty
        ? ''
        : '?action=${Uri.encodeQueryComponent(action)}';
    ref.read(appRouterProvider).go('/reminder/$occurrenceId$query');
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'DoseDiary',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(textScaleFactor: settings.textScaleFactor),
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('si'),
        Locale('ta'),
      ],
      locale: settings.locale,
      builder: (context, child) {
        // Apply global text scale
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(settings.textScaleFactor),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
