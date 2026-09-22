import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// DoseDiary pill-and-clock logo widget.
/// Renders a styled icon that represents the app brand.
class DdLogo extends StatelessWidget {
  const DdLogo({super.key, this.size = AppDimensions.logoMd, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final bgColor = onDark ? Colors.white.withOpacity(0.15) : AppColors.primaryAction.withOpacity(0.08);
    final iconColor = onDark ? Colors.white : AppColors.primaryAction;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.medication_rounded, size: size * 0.5, color: iconColor),
          Positioned(
            right: size * 0.12,
            bottom: size * 0.12,
            child: Container(
              decoration: BoxDecoration(
                color: onDark ? Colors.white : AppColors.primaryAction,
                shape: BoxShape.circle,
              ),
              padding: EdgeInsets.all(size * 0.04),
              child: Icon(
                Icons.alarm_rounded,
                size: size * 0.22,
                color: onDark ? AppColors.primaryAction : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
