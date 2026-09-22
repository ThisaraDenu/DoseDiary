import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// DoseDiary primary and secondary buttons.
class DdButton extends StatelessWidget {
  const DdButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = DdButtonVariant.primary,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final DdButtonVariant variant;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = enabled && !isLoading && onPressed != null;

    return switch (variant) {
      DdButtonVariant.primary => ElevatedButton(
          onPressed: isEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isEnabled ? AppColors.primaryAction : AppColors.borderLight,
            foregroundColor: AppColors.textOnPrimary,
            minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
            ),
            elevation: 0,
          ),
          child: _ButtonChild(label: label, isLoading: isLoading, icon: icon, onPrimary: true),
        ),
      DdButtonVariant.secondary => OutlinedButton(
          onPressed: isEnabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
            side: BorderSide(
              color: isEnabled ? AppColors.textPrimary : AppColors.borderLight,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
            ),
          ),
          child: _ButtonChild(label: label, isLoading: isLoading, icon: icon, onPrimary: false),
        ),
      DdButtonVariant.text => TextButton(
          onPressed: isEnabled ? onPressed : null,
          child: _ButtonChild(label: label, isLoading: isLoading, icon: icon, onPrimary: false),
        ),
      DdButtonVariant.danger => ElevatedButton(
          onPressed: isEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.textOnPrimary,
            minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
            ),
            elevation: 0,
          ),
          child: _ButtonChild(label: label, isLoading: isLoading, icon: icon, onPrimary: true),
        ),
    };
  }
}

enum DdButtonVariant { primary, secondary, text, danger }

class _ButtonChild extends StatelessWidget {
  const _ButtonChild({
    required this.label,
    required this.isLoading,
    required this.onPrimary,
    this.icon,
  });
  final String label;
  final bool isLoading;
  final bool onPrimary;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: onPrimary ? AppColors.textOnPrimary : AppColors.primaryAction,
        ),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [icon!, const SizedBox(width: 8), Text(label)],
      );
    }
    return Text(label);
  }
}
