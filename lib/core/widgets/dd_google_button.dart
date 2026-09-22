import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// A polished, accessible "Continue with Google" button conforming to Google's
/// official Identity branding guidelines.
///
/// Features:
/// • Pixel-perfect 4-color Google "G" vector icon (zero external asset dependency)
/// • Subtle elevated surface with soft drop-shadow
/// • Inline circular progress indicator during authentication
/// • Full accessibility labels and tactile press feedback
class DdGoogleButton extends StatelessWidget {
  const DdGoogleButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Continue with Google',
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = !isLoading && onPressed != null;

    return Container(
      width: double.infinity,
      height: AppDimensions.buttonHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.cardSurface,
          foregroundColor: AppColors.textPrimary,
          disabledBackgroundColor: AppColors.cardSurface,
          side: const BorderSide(
            color: AppColors.borderMedium,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryAction,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Signing in...',
                    style: AppTextStyles.labelLg(color: AppColors.textSecondary),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GoogleLogo(size: 22),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: AppTextStyles.labelLg(
                      color: isEnabled
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Zero-dependency pixel-perfect 4-color Google "G" logo rendered via CustomPainter.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.width / 2;
    final center = Offset(r, r);
    final double strokeWidth = size.width * 0.22;
    final double innerRadius = r - strokeWidth;

    // Official Google Brand Colors
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    const overlap = 0.03; // In radians to avoid sub-pixel seams

    // 1. Red Sector (Top: ~200° to 335°)
    _drawDonutSector(
      canvas,
      center,
      innerRadius,
      r,
      -math.pi * 0.9,
      math.pi * 0.75 + overlap,
      redPaint,
    );

    // 2. Yellow Sector (Left: ~110° to 205°)
    _drawDonutSector(
      canvas,
      center,
      innerRadius,
      r,
      math.pi * 0.55,
      math.pi * 0.55 + overlap,
      yellowPaint,
    );

    // 3. Green Sector (Bottom: ~15° to 120°)
    _drawDonutSector(
      canvas,
      center,
      innerRadius,
      r,
      math.pi * 0.08,
      math.pi * 0.55 + overlap,
      greenPaint,
    );

    // 4. Blue Sector (Right lower curve: -20° to 25°)
    _drawDonutSector(
      canvas,
      center,
      innerRadius,
      r,
      -math.pi * 0.12,
      math.pi * 0.35 + overlap,
      bluePaint,
    );

    // 5. Blue Horizontal Bar (Extends from center past the right edge)
    final barHeight = strokeWidth;
    final barRect = Rect.fromLTRB(
      center.dx - 1.0,
      center.dy - barHeight / 2,
      size.width,
      center.dy + barHeight / 2,
    );
    canvas.drawRect(barRect, bluePaint);
  }

  void _drawDonutSector(
    Canvas canvas,
    Offset center,
    double innerR,
    double outerR,
    double startAngle,
    double sweepAngle,
    Paint paint,
  ) {
    final path = Path();
    final outerRect = Rect.fromCircle(center: center, radius: outerR);
    final innerRect = Rect.fromCircle(center: center, radius: innerR);

    path.arcTo(outerRect, startAngle, sweepAngle, false);
    path.arcTo(innerRect, startAngle + sweepAngle, -sweepAngle, false);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
