import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';

/// Full-screen loading indicator.
class DdLoadingScreen extends StatelessWidget {
  const DdLoadingScreen({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primaryAction),
              if (message != null) ...[
                const SizedBox(height: AppDimensions.stackLg),
                Text(message!, style: AppTextStyles.bodyLg(color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
      );
}

/// Inline loading indicator.
class DdLoading extends StatelessWidget {
  const DdLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.stackXl),
          child: CircularProgressIndicator(color: AppColors.primaryAction),
        ),
      );
}

/// Empty-state widget with icon, title, and optional action.
class DdEmptyState extends StatelessWidget {
  const DdEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.stack2Xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.borderMedium),
            const SizedBox(height: AppDimensions.stackLg),
            Text(title, style: AppTextStyles.headlineMd(), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: AppDimensions.stackMd),
              Text(
                subtitle!,
                style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: AppDimensions.stackXl),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(backgroundColor: AppColors.primaryAction),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Offline banner shown at the top of screens.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.snoozedBackground,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.screenMargin,
        vertical: AppDimensions.stackSm,
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 16, color: AppColors.snoozedForeground),
          const SizedBox(width: AppDimensions.stackSm),
          Text(
            'Offline — changes will sync when connected',
            style: AppTextStyles.caption(color: AppColors.snoozedForeground),
          ),
        ],
      ),
    );
  }
}

/// App bar with optional back button, title, and trailing actions.
class DdAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DdAppBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.actions,
    this.bottom,
  });

  final String title;
  final bool showBack;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) => AppBar(
        title: Text(title),
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Back',
              )
            : null,
        automaticallyImplyLeading: showBack,
        actions: actions,
        bottom: bottom,
      );

  @override
  Size get preferredSize => Size.fromHeight(bottom == null ? kToolbarHeight : kToolbarHeight + bottom!.preferredSize.height);
}
