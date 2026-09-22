import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// DoseDiary typography system.
/// Based on the Stitch design system (Inter font family).
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _inter({
    required double size,
    required FontWeight weight,
    double? height,
    double? letterSpacing,
    Color color = AppColors.textPrimary,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
      );

  // ── Display ───────────────────────────────────────────────
  /// 32 / 700 — App name on splash/onboarding
  static TextStyle displayLg({Color? color}) => _inter(
        size: 32,
        weight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.32,
        color: color ?? AppColors.textPrimary,
      );

  /// 26 / 700 — Medication name
  static TextStyle displayMedication({Color? color}) => _inter(
        size: 26,
        weight: FontWeight.w700,
        height: 1.31,
        letterSpacing: -0.26,
        color: color ?? AppColors.textPrimary,
      );

  // ── Headlines ────────────────────────────────────────────
  /// 24 / 700 — Screen heading
  static TextStyle headlineLg({Color? color}) => _inter(
        size: 24,
        weight: FontWeight.w700,
        height: 1.33,
        color: color ?? AppColors.textPrimary,
      );

  /// 20 / 600 — Section heading
  static TextStyle headlineMd({Color? color}) => _inter(
        size: 20,
        weight: FontWeight.w600,
        height: 1.4,
        color: color ?? AppColors.textPrimary,
      );

  // ── Body ─────────────────────────────────────────────────
  /// 18 / 400 — Primary body text
  static TextStyle bodyXl({Color? color}) => _inter(
        size: 18,
        weight: FontWeight.w400,
        height: 1.56,
        letterSpacing: 0.18,
        color: color ?? AppColors.textPrimary,
      );

  /// 16 / 400 — Secondary body text
  static TextStyle bodyLg({Color? color}) => _inter(
        size: 16,
        weight: FontWeight.w400,
        height: 1.63,
        letterSpacing: 0.16,
        color: color ?? AppColors.textPrimary,
      );

  /// 16 / 600 — Bold body / section label
  static TextStyle bodyBold({Color? color}) => _inter(
        size: 16,
        weight: FontWeight.w600,
        height: 1.5,
        letterSpacing: 0.16,
        color: color ?? AppColors.textPrimary,
      );

  // ── Labels ────────────────────────────────────────────────
  /// 16 / 600 — Button labels, nav labels (active)
  static TextStyle labelLg({Color? color}) => _inter(
        size: 16,
        weight: FontWeight.w600,
        height: 1.38,
        letterSpacing: 0.32,
        color: color ?? AppColors.textPrimary,
      );

  /// 14 / 600 — Secondary labels, nav labels (inactive)
  static TextStyle labelMd({Color? color}) => _inter(
        size: 14,
        weight: FontWeight.w600,
        height: 1.43,
        letterSpacing: 0.28,
        color: color ?? AppColors.textPrimary,
      );

  // ── Caption ───────────────────────────────────────────────
  /// 13 / 500 — Supporting text, timestamps
  static TextStyle caption({Color? color}) => _inter(
        size: 13,
        weight: FontWeight.w500,
        height: 1.38,
        letterSpacing: 0.26,
        color: color ?? AppColors.textTertiary,
      );

  // ── Status badge ─────────────────────────────────────────
  /// 13 / 700 — Status chip text
  static TextStyle statusBadge({Color? color}) => _inter(
        size: 13,
        weight: FontWeight.w700,
        height: 1.38,
        letterSpacing: 0.26,
        color: color ?? AppColors.textPrimary,
      );
}
