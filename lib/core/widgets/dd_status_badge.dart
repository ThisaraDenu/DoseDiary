import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import '../../data/local/models/dose_status.dart';

/// Status badge — always pairs icon + text label.
class DdStatusBadge extends StatelessWidget {
  const DdStatusBadge({super.key, required this.status});

  final DoseStatus status;

  @override
  Widget build(BuildContext context) {
    final config = _statusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: config.background,
        borderRadius: BorderRadius.circular(AppDimensions.badgeRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: AppDimensions.iconStatus, color: config.foreground),
          const SizedBox(width: 4),
          Text(config.label, style: AppTextStyles.statusBadge(color: config.foreground)),
        ],
      ),
    );
  }

  static _StatusConfig _statusConfig(DoseStatus status) => switch (status) {
        DoseStatus.taken => const _StatusConfig(
            label: 'Taken',
            icon: Icons.check_circle_rounded,
            foreground: AppColors.takenForeground,
            background: AppColors.takenBackground,
          ),
        DoseStatus.missed => const _StatusConfig(
            label: 'Missed',
            icon: Icons.cancel_rounded,
            foreground: AppColors.missedForeground,
            background: AppColors.missedBackground,
          ),
        DoseStatus.skipped => const _StatusConfig(
            label: 'Skipped',
            icon: Icons.skip_next_rounded,
            foreground: AppColors.skippedForeground,
            background: AppColors.skippedBackground,
          ),
        DoseStatus.pending => const _StatusConfig(
            label: 'Pending',
            icon: Icons.schedule_rounded,
            foreground: AppColors.pendingForeground,
            background: AppColors.pendingBackground,
          ),
        DoseStatus.overdue => const _StatusConfig(
            label: 'Overdue',
            icon: Icons.warning_amber_rounded,
            foreground: AppColors.overdueForeground,
            background: AppColors.overdueBackground,
          ),
        DoseStatus.snoozed => const _StatusConfig(
            label: 'Snoozed',
            icon: Icons.alarm_rounded,
            foreground: AppColors.snoozedForeground,
            background: AppColors.snoozedBackground,
          ),
      };
}

class _StatusConfig {
  const _StatusConfig({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });
  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
}
