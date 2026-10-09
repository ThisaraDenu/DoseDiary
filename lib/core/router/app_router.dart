import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/login/login_screen.dart';
import '../../features/auth/signup/signup_screen.dart';
import '../../features/auth/verify_email/email_verification_screen.dart';
import '../../features/auth/complete_profile/complete_google_profile_screen.dart';
import '../../features/auth/forgot_password/forgot_password_screen.dart';
import '../../features/home/home_dashboard_screen.dart';
import '../../features/medications/medication_schedule_screen.dart';
import '../../features/medications/add_medication_screen.dart';
import '../../features/medications/edit_medication_screen.dart';
import '../../features/reminders/reminder_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/refills/refills_screen.dart';
import '../../features/caregivers/caregiver_management_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/accessibility_screen.dart';
import '../../features/settings/settings_detail_screens.dart';
import '../../features/permissions/permissions_screen.dart';
import '../../features/adherence/medication_adherence_screen.dart';
import '../../core/widgets/dd_bottom_nav.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (ctx, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        builder: (ctx, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (ctx, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.signup,
        builder: (ctx, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: RouteNames.verifyEmail,
        builder: (ctx, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final email = extra['email'] as String? ?? '';
          return EmailVerificationScreen(email: email);
        },
      ),
      GoRoute(
        path: RouteNames.completeGoogleProfile,
        builder: (ctx, state) => const CompleteGoogleProfileScreen(),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (ctx, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RouteNames.permissions,
        builder: (ctx, state) => const PermissionsScreen(),
      ),
      GoRoute(
        path: RouteNames.reminder,
        builder: (ctx, state) {
          final id = state.pathParameters['id'] ?? '';
          return ReminderScreen(
            occurrenceId: id,
            initialAction: state.uri.queryParameters['action'],
          );
        },
      ),
      GoRoute(
        path: RouteNames.caregiverAlert,
        builder: (ctx, state) {
          final id = state.pathParameters['id'] ?? '';
          return CaregiverAlertScreen(alertId: id);
        },
      ),
      // Main shell with bottom navigation
      ShellRoute(
        builder: (ctx, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.home,
            builder: (ctx, state) => const HomeDashboardScreen(),
          ),
          GoRoute(
            path: RouteNames.medications,
            builder: (ctx, state) => const MedicationScheduleScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (ctx, state) => const AddMedicationScreen(),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (ctx, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return EditMedicationScreen(medicationId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.refills,
            builder: (ctx, state) => const RefillsScreen(),
            routes: [
              GoRoute(
                path: 'confirm/:id',
                builder: (ctx, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return RefillConfirmScreen(medicationId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.adherence,
            builder: (ctx, state) => const MedicationAdherenceScreen(),
          ),
          GoRoute(
            path: RouteNames.caregivers,
            builder: (ctx, state) => const CaregiverManagementScreen(),
            routes: [
              GoRoute(
                path: 'invite',
                builder: (ctx, state) => const InviteCaregiverScreen(),
              ),
              GoRoute(
                path: 'dashboard',
                builder: (ctx, state) => const CaregiverDashboardScreen(),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.history,
            builder: (ctx, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: RouteNames.settings,
            builder: (ctx, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'accessibility',
                builder: (ctx, state) => const AccessibilityScreen(),
              ),
              GoRoute(
                path: 'notifications',
                builder: (ctx, state) => const NotificationSettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'centre',
                    builder: (ctx, state) => const NotificationCentreScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: 'privacy',
                builder: (ctx, state) => const PrivacyScreen(),
              ),
              GoRoute(
                path: 'account',
                builder: (ctx, state) => const AccountScreen(),
              ),
              GoRoute(
                path: 'safety',
                builder: (ctx, state) => const SafetyInfoScreen(),
              ),
              GoRoute(
                path: 'help',
                builder: (ctx, state) => const HelpScreen(),
              ),
              GoRoute(
                path: 'data-sync',
                builder: (ctx, state) => const DataSyncSettingsScreen(),
              ),
              GoRoute(
                path: 'security',
                builder: (ctx, state) => const SecuritySettingsScreen(),
              ),
              GoRoute(
                path: 'about',
                builder: (ctx, state) => const AboutSettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (ctx, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
});
