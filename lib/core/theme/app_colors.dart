import 'package:flutter/material.dart';

/// DoseDiary brand colour palette.
/// Matches the "MediCare Accessible UI Prototype" Stitch design system.
class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────
  static const Color primaryBackground = Color(0xFFF9F9F9); // Clean modern grey
  static const Color primaryAction = Color(0xFFDC143C);     // Crimson
  static const Color primaryActionDark = Color(0xFFB91032); // Pressed crimson

  // ── Surface ───────────────────────────────────────────────
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color scaffoldBackground = Color(0xFFF9F9F9);

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
  static const Color navBarActive = Color(0xFFDC143C);

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
