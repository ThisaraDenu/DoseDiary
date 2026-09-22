/// Route name constants for go_router.
class RouteNames {
  RouteNames._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  // Main shell (bottom nav)
  static const String home = '/home';
  static const String medications = '/medications';
  static const String history = '/history';
  static const String settings = '/settings';

  // Medications sub-routes
  static const String addMedication = '/medications/add';
  static const String editMedication = '/medications/:id/edit';

  // Reminder
  static const String reminder = '/reminder/:id';

  // Refills
  static const String refills = '/refills';
  static const String refillConfirm = '/refills/confirm/:id';

  // Caregivers
  static const String caregivers = '/caregivers';
  static const String inviteCaregiver = '/caregivers/invite';
  static const String caregiverDashboard = '/caregivers/dashboard';
  static const String caregiverAlert = '/caregivers/alert/:id';

  // Settings sub-routes
  static const String settingsAccessibility = '/settings/accessibility';
  static const String settingsNotifications = '/settings/notifications';
  static const String settingsPrivacy = '/settings/privacy';
  static const String settingsAccount = '/settings/account';
  static const String settingsSafety = '/settings/safety';
  static const String settingsHelp = '/settings/help';
  static const String notificationCentre = '/settings/notifications/centre';
}
