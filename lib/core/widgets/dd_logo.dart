import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// DoseDiary official brand logo widget.
/// Renders the heart-and-pills app logo image from assets.
class DdLogo extends StatelessWidget {
  const DdLogo({super.key, this.size = AppDimensions.logoMd, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/images/app_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: onDark ? Colors.white.withOpacity(0.15) : AppColors.primaryAction.withOpacity(0.08),
              borderRadius: BorderRadius.circular(size * 0.22),
            ),
            child: Icon(
              Icons.favorite_rounded,
              size: size * 0.55,
              color: onDark ? Colors.white : AppColors.primaryAction,
            ),
          );
        },
      ),
    );
  }
}
