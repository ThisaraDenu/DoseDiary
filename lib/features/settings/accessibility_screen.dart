import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/dd_card.dart';
import '../../core/widgets/dd_empty_state.dart';
import '../../core/services/permission_service.dart';
import '../../services/notification_service.dart';
import '../../services/dose_alarm_scheduler.dart';
import '../../data/local/models/app_notification.dart';
import '../../data/repositories/notification_repository.dart';
import 'settings_providers.dart';

export 'account_screen.dart' show AccountScreen;

class AccessibilityScreen extends ConsumerWidget {
  const AccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(title: const Text('Accessibility')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.screenMargin),
        children: [
          // Text size
          DdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Text Size', style: AppTextStyles.bodyBold()),
                const SizedBox(height: AppDimensions.stackSm),
                Text(
                  'Preview text — ${_scaleLabel(settings.textScaleFactor)}',
                  style: AppTextStyles.bodyLg().copyWith(
                    fontSize: 16 * settings.textScaleFactor,
                  ),
                ),
                const SizedBox(height: AppDimensions.stackMd),
                Slider(
                  value: settings.textScaleFactor,
                  min: 0.8,
                  max: 1.6,
                  divisions: 8,
                  activeColor: AppColors.primaryAction,
                  label: _scaleLabel(settings.textScaleFactor),
                  onChanged: (v) => notifier.setTextScale(v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Smaller', style: AppTextStyles.caption()),
                    Text('Larger', style: AppTextStyles.caption()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.stackLg),

          // Simple wording
          DdCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Simpler Language', style: AppTextStyles.bodyBold()),
                      const SizedBox(height: 4),
                      Text(
                        'Use shorter, plainer words throughout the app.',
                        style: AppTextStyles.bodyLg(
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: settings.simpleWording,
                  onChanged: (v) => notifier.setSimpleWording(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.stackLg),

          // Language
          DdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Language', style: AppTextStyles.bodyBold()),
                const SizedBox(height: AppDimensions.stackSm),
                for (final lang in [
                  ('en', 'English'),
                  ('si', 'Sinhala (සිංහල)'),
                  ('ta', 'Tamil (தமிழ்)')
                ])
                  RadioListTile<String>(
                    title: Text(lang.$2, style: AppTextStyles.bodyXl()),
                    value: lang.$1,
                    groupValue: settings.locale.languageCode,
                    activeColor: AppColors.primaryAction,
                    onChanged: (v) => notifier.setLanguage(v!),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _scaleLabel(double scale) {
    if (scale <= 0.85) return 'Small';
    if (scale <= 0.95) return 'Normal–Small';
    if (scale <= 1.05) return 'Normal';
    if (scale <= 1.15) return 'Large';
    if (scale <= 1.35) return 'Extra Large';
    return 'Largest';
  }
}

// ── Notification Settings ─────────────────────────────────────────────────────

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.screenMargin),
        children: [
          DdCard(
            child: Column(
              children: [
                _SwitchRow(
                  label: 'Medication Reminders',
                  subtitle: 'Notify me when a dose is due',
                  value: settings.notificationRemindersEnabled,
                  onChanged: (value) async {
                    if (value) {
                      final granted = await PermissionService.request(
                        AppPermissionType.notification,
                      );
                      if (!granted) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Enable notifications in device settings to receive reminders.',
                            ),
                          ),
                        );
                        return;
                      }
                    } else {
                      await NotificationService.cancelAll();
                    }
                    if (value) {
                      await NotificationService.requestAlarmPermissions();
                    }
                    await notifier.setNotificationReminders(value);
                    if (value) {
                      await DoseAlarmScheduler.syncUpcomingAlarms();
                    }
                  },
                ),
                const Divider(),
                _SwitchRow(
                  label: 'Sound',
                  subtitle: 'Play a sound with notifications',
                  value: settings.notificationSound,
                  onChanged: (v) => notifier.setNotificationSound(v),
                ),
                const Divider(),
                _SwitchRow(
                  label: 'Vibration',
                  subtitle: 'Vibrate with notifications',
                  value: settings.notificationVibration,
                  onChanged: (v) => notifier.setNotificationVibration(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.stackXl),
          Text('Retry & Grace Period', style: AppTextStyles.headlineMd()),
          const SizedBox(height: AppDimensions.stackSm),
          Text(
            'If you don\'t respond, DoseDiary will send up to ${settings.retryCount} follow-up reminders. Caregiver alerts go out after ${settings.gracePeriodMinutes} minutes.',
            style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.stackLg),
          DdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Follow-up reminders: ${settings.retryCount}',
                    style: AppTextStyles.bodyBold()),
                Slider(
                  value: settings.retryCount.toDouble(),
                  min: 0,
                  max: 5,
                  divisions: 5,
                  activeColor: AppColors.primaryAction,
                  label: settings.retryCount.toString(),
                  onChanged: (v) => notifier.setRetryCount(v.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.stackLg),
          DdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Caregiver alert after: ${settings.gracePeriodMinutes} min',
                    style: AppTextStyles.bodyBold()),
                Slider(
                  value: settings.gracePeriodMinutes.toDouble(),
                  min: 15,
                  max: 120,
                  divisions: 7,
                  activeColor: AppColors.primaryAction,
                  label: '${settings.gracePeriodMinutes} min',
                  onChanged: (v) => notifier.setGracePeriod(v.round()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        title: Text(label, style: AppTextStyles.bodyBold()),
        subtitle: subtitle != null
            ? Text(subtitle!, style: AppTextStyles.caption())
            : null,
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryAction,
        contentPadding: EdgeInsets.zero,
      );
}

// ── Privacy ───────────────────────────────────────────────────────────────────

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      backgroundColor: AppColors.scaffoldBackground,
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.screenMargin),
        children: [
          DdCard(
            child: _SwitchRow(
              label: 'Safe Notification Previews',
              subtitle:
                  'Show only "Dose reminder" in lock-screen notifications instead of medicine names.',
              value: settings.privacySafePreviews,
              onChanged: (v) => notifier.setPrivacySafePreviews(v),
            ),
          ),
          const SizedBox(height: AppDimensions.stackLg),
          DdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Data Storage', style: AppTextStyles.bodyBold()),
                const SizedBox(height: AppDimensions.stackSm),
                Text(
                  'Your medication records are stored locally on this device and optionally synced to a secure cloud account when you sign in.',
                  style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Safety Info ────────────────────────────────────────────────────────────────

class SafetyInfoScreen extends StatelessWidget {
  const SafetyInfoScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Medical Safety Notice')),
        backgroundColor: AppColors.scaffoldBackground,
        body: ListView(
          padding: const EdgeInsets.all(AppDimensions.screenMargin),
          children: [
            DdCard(
              borderColor: AppColors.primaryAction.withOpacity(0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.health_and_safety_rounded,
                          color: AppColors.primaryAction),
                      const SizedBox(width: 8),
                      Text('Important Notice',
                          style: AppTextStyles.bodyBold(
                              color: AppColors.primaryAction)),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.stackMd),
                  Text(
                    'DoseDiary is a personal medication reminder and adherence tracking tool.\n\n'
                    'This app does NOT:\n'
                    '• Diagnose medical conditions\n'
                    '• Recommend treatment changes\n'
                    '• Calculate recommended dosages\n'
                    '• Give medical instructions\n'
                    '• Replace professional medical advice\n\n'
                    'Always follow the instructions of your doctor, pharmacist, or other qualified healthcare provider.\n\n'
                    'If you have any concerns about your medication, contact your healthcare provider immediately.',
                    style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

// ── Help ───────────────────────────────────────────────────────────────────────

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Help & Support')),
        backgroundColor: AppColors.scaffoldBackground,
        body: ListView(
          padding: const EdgeInsets.all(AppDimensions.screenMargin),
          children: const [
            _FaqItem(
              question: 'How do I add a medication?',
              answer:
                  'Go to the Medications tab and tap the "+" button. Fill in the medicine name, strength, dose, and set reminder times.',
            ),
            _FaqItem(
              question: 'What happens if I miss a dose?',
              answer:
                  'DoseDiary marks the dose as missed in your history. Your caregiver (if set up) will receive an alert if you don\'t respond within the grace period.',
            ),
            _FaqItem(
              question: 'How do caregivers access my schedule?',
              answer:
                  'Go to Settings → Caregivers and invite someone by email. You choose exactly what they can see.',
            ),
            _FaqItem(
              question: 'Does the app tell me what dose to take?',
              answer:
                  'No. DoseDiary only reminds you of the schedule you set up yourself. It does not give medical advice or calculate doses.',
            ),
            _FaqItem(
              question: 'Is my data private?',
              answer:
                  'Your data is stored locally on this device and can sync to your secure account. Approved caregivers only receive the information allowed by the connection permissions you choose.',
            ),
          ],
        ),
      );
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.stackMd),
        child: DdCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: AppDimensions.stackSm),
            title: Text(question, style: AppTextStyles.bodyBold()),
            children: [
              Text(answer,
                  style: AppTextStyles.bodyLg(color: AppColors.textSecondary))
            ],
          ),
        ),
      );
}

// ── Notification Centre ───────────────────────────────────────────────────────

class NotificationCentreScreen extends ConsumerStatefulWidget {
  const NotificationCentreScreen({super.key});

  @override
  ConsumerState<NotificationCentreScreen> createState() =>
      _NotificationCentreScreenState();
}

class _NotificationCentreScreenState
    extends ConsumerState<NotificationCentreScreen> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationRepositoryProvider).markAllRead();
              _refresh();
            },
            child: const Text('Mark all read'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'clear_read') {
                await ref.read(notificationRepositoryProvider).clearRead();
                _refresh();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'clear_read',
                child: Text('Clear read notifications'),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: AppColors.scaffoldBackground,
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: DdEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load notifications',
            subtitle: error.toString(),
            actionLabel: 'Try again',
            onAction: _refresh,
          ),
        ),
        data: (notifications) {
          final visible = _unreadOnly
              ? notifications.where((item) => !item.isRead).toList()
              : notifications;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: !_unreadOnly,
                          onSelected: (_) =>
                              setState(() => _unreadOnly = false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Unread'),
                          selected: _unreadOnly,
                          onSelected: (_) => setState(() => _unreadOnly = true),
                        ),
                        const Spacer(),
                        Text(
                          '${notifications.where((item) => !item.isRead).length} unread',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (visible.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: DdEmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'No notifications',
                      subtitle: 'Reminders and alerts will appear here.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    sliver: SliverList.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _notificationCard(visible[index]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _notificationCard(AppNotification notification) {
    final color = _priorityColor(notification.priority);
    final isUnread = !notification.isRead;
    final hasDestination =
        notification.route != null && notification.route!.isNotEmpty;
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFE66A76), Color(0xFFB1002C)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.white, size: 21),
              SizedBox(width: 7),
              Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      onDismissed: (_) async {
        await ref
            .read(notificationRepositoryProvider)
            .deleteNotification(notification.id);
        _refresh();
      },
      child: Semantics(
        button: true,
        label: notification.title,
        child: Container(
          key: ValueKey('notification-card-${notification.id}'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isUnread
                  ? [
                      Color.alphaBlend(
                        color.withOpacity(0.13),
                        Colors.white,
                      ),
                      Colors.white,
                      Color.alphaBlend(
                        color.withOpacity(0.045),
                        const Color(0xFFFFFCFA),
                      ),
                    ]
                  : const [
                      Colors.white,
                      Color(0xFFFFFCFA),
                    ],
              stops: isUnread ? const [0, 0.55, 1] : null,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  isUnread ? color.withOpacity(0.28) : const Color(0xFFEDE7E4),
            ),
            boxShadow: [
              BoxShadow(
                color: isUnread
                    ? color.withOpacity(0.12)
                    : const Color(0x0A3D2424),
                blurRadius: isUnread ? 22 : 12,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 20,
                bottom: 20,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: isUnread ? color : color.withOpacity(0.35),
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(99),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -28,
                top: -34,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(isUnread ? 0.045 : 0.018),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () async {
                    await ref
                        .read(notificationRepositoryProvider)
                        .markRead(notification.id);
                    _refresh();
                    if (!mounted || !hasDestination) return;
                    context.go(notification.route!);
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 17, 16, 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _NotificationIconTile(
                              icon: _typeIcon(notification.type),
                              color: color,
                              isUnread: isUnread,
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 7,
                                    runSpacing: 5,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      _NotificationTypeBadge(
                                        label: _typeLabel(notification.type),
                                        color: color,
                                      ),
                                      if (isUnread)
                                        _NotificationUnreadBadge(color: color),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    notification.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.25,
                                      letterSpacing: -0.1,
                                      fontWeight: isUnread
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                      color: const Color(0xFF211819),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: Text(
                            notification.body,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.48,
                              color: notification.isRead
                                  ? const Color(0xFF705F60)
                                  : const Color(0xFF503D3F),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          height: 1,
                          color: color.withOpacity(isUnread ? 0.1 : 0.06),
                        ),
                        const SizedBox(height: 11),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 15,
                              color: color.withOpacity(0.75),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _timeLabel(notification.createdAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF756668),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            if (hasDestination) ...[
                              Text(
                                'View details',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: color,
                              ),
                            ] else
                              Icon(
                                notification.isRead
                                    ? Icons.done_all_rounded
                                    : Icons.circle,
                                size: notification.isRead ? 17 : 7,
                                color: notification.isRead
                                    ? const Color(0xFF9A8C8E)
                                    : color,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    if (type.contains('refill')) return 'REFILL';
    if (type.contains('invitation')) return 'INVITATION';
    if (type.contains('connection')) return 'CONNECTION';
    if (type.contains('missed')) return 'MISSED DOSE';
    if (type.contains('overdue')) return 'OVERDUE';
    if (type.contains('taken')) return 'DOSE TAKEN';
    if (type.contains('alert')) return 'CARE ALERT';
    return 'MEDICATION';
  }

  void _refresh() {
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'critical':
        return const Color(0xFFB1002C);
      case 'high':
        return const Color(0xFFE56A00);
      case 'silent':
        return const Color(0xFF545F73);
      default:
        return const Color(0xFF006448);
    }
  }

  IconData _typeIcon(String type) {
    if (type.contains('refill')) return Icons.inventory_2_outlined;
    if (type.contains('invitation') || type.contains('connection')) {
      return Icons.people_outline_rounded;
    }
    if (type.contains('missed') || type.contains('overdue')) {
      return Icons.notification_important_outlined;
    }
    if (type.contains('taken')) return Icons.check_circle_outline_rounded;
    if (type.contains('alert')) return Icons.warning_amber_rounded;
    return Icons.medication_outlined;
  }

  String _timeLabel(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat.yMMMd().format(dateTime);
  }
}

class _NotificationIconTile extends StatelessWidget {
  const _NotificationIconTile({
    required this.icon,
    required this.color,
    required this.isUnread,
  });

  final IconData icon;
  final Color color;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(color.withOpacity(0.2), Colors.white),
                  Color.alphaBlend(color.withOpacity(0.08), Colors.white),
                ],
              ),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: color.withOpacity(0.18)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          if (isUnread)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationTypeBadge extends StatelessWidget {
  const _NotificationTypeBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          height: 1.1,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _NotificationUnreadBadge extends StatelessWidget {
  const _NotificationUnreadBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          height: 1.1,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
