import 'package:flutter/material.dart';

/// Accessible app accent choices. Each colour is dark enough to keep white
/// labels readable and is identified by text as well as colour in the UI.
enum AppThemeColor {
  crimson(
    label: 'Crimson',
    description: 'DoseDiary classic',
    color: Color(0xFFDC143C),
    darkColor: Color(0xFFB91032),
  ),
  oceanBlue(
    label: 'Ocean Blue',
    description: 'Clear and calm',
    color: Color(0xFF0057B8),
    darkColor: Color(0xFF003F87),
  ),
  teal(
    label: 'Teal',
    description: 'Colour-vision friendly',
    color: Color(0xFF006B5E),
    darkColor: Color(0xFF004D43),
  ),
  violet(
    label: 'Violet',
    description: 'Distinct and balanced',
    color: Color(0xFF5B3FC4),
    darkColor: Color(0xFF40279B),
  ),
  highContrast(
    label: 'High Contrast',
    description: 'Strongest definition',
    color: Color(0xFF111827),
    darkColor: Color(0xFF030712),
  );

  const AppThemeColor({
    required this.label,
    required this.description,
    required this.color,
    required this.darkColor,
  });

  final String label;
  final String description;
  final Color color;
  final Color darkColor;

  static AppThemeColor fromName(String? name) {
    return AppThemeColor.values.firstWhere(
      (option) => option.name == name,
      orElse: () => AppThemeColor.crimson,
    );
  }
}

/// DoseDiary brand colour palette.
/// Matches the "MediCare Accessible UI Prototype" Stitch design system.
class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────
  static const Color primaryBackground = Color(0xFFF9F9F9); // Clean modern grey
  static Color _primaryAction = AppThemeColor.crimson.color;
  static Color _primaryActionDark = AppThemeColor.crimson.darkColor;

  static Color get primaryAction => _primaryAction;
  static Color get primaryActionDark => _primaryActionDark;

  /// Keeps legacy components that use AppColors in sync with Material theme.
  static void applyThemeColor(AppThemeColor themeColor) {
    _primaryAction = themeColor.color;
    _primaryActionDark = themeColor.darkColor;
  }

  // ── Surface ───────────────────────────────────────────────
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color scaffoldBackground = Color(0xFFF9F9F9);
  static const Color onboardingBackground =
      Color(0xFFF3EFE8); // Warm cream from design mockups
  static const Color onboardingDotInactive =
      Color(0xFFD1CDC5); // Neutral inactive dot

  // ── Text ─────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF5C3F3F);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Borders / Dividers ────────────────────────────────────
  static const Color borderLight = Color(0xFFEEEEEE);
  static const Color borderMedium = Color(0xFFE2E2E2);
  static const Color borderDark = Color(0xFF916F6E);

  // ── Navigation ────────────────────────────────────────────
  static const Color navBarBackground = Color(0xFFFFFFFF);
  static const Color navBarBorder = Color(0xFFEEEEEE);
  static const Color navBarInactive = Color(0xFF64748B);
  static Color get navBarActive => _primaryAction;

  // ── Status: Taken ─────────────────────────────────────────
  static const Color takenForeground = Color(0xFF047857);
  static const Color takenBackground = Color(0xFFECFDF5);

  // ── Status: Missed ────────────────────────────────────────
  static const Color missedForeground = Color(0xFF475569);
  static const Color missedBackground = Color(0xFFF1F5F9);

  // ── Status: Skipped ───────────────────────────────────────
  static const Color skippedForeground = Color(0xFFB45309);
  static const Color skippedBackground = Color(0xFFFFFBEB);

  // ── Status: Pending ───────────────────────────────────────
  static const Color pendingForeground = Color(0xFFDC143C);
  static const Color pendingBackground = Color(0xFFFEF2F2);

  // ── Status: Overdue ───────────────────────────────────────
  static const Color overdueForeground = Color(0xFF9B1C1C);
  static const Color overdueBackground = Color(0xFFFEE2E2);

  // ── Status: Snoozed ──────────────────────────────────────
  static const Color snoozedForeground = Color(0xFF92400E);
  static const Color snoozedBackground = Color(0xFFFFF7ED);

  // ── Utility ──────────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color success = Color(0xFF047857);
  static const Color warning = Color(0xFFB45309);
  static const Color info = Color(0xFF1D4ED8);

  // ── Shadows ──────────────────────────────────────────────
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> navBarShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 16,
      offset: Offset(0, -4),
    ),
  ];
}
