import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/dd_logo.dart';
import '../../core/router/route_names.dart';
import '../../data/remote/auth_service.dart';
import '../../data/repositories/app_repositories.dart';
import '../home/home_dashboard_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = AuthService.currentUser;
    final userName = user?.userMetadata?['full_name'] as String? ??
        (user?.email?.split('@').first ?? 'Guest User');
    final userEmail = user?.email ?? 'Not signed in';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          // App brand header
          Container(
            color: AppColors.cardSurface,
            padding: const EdgeInsets.all(AppDimensions.cardPadding),
            child: Row(
              children: [
                const DdLogo(size: 48),
                const SizedBox(width: AppDimensions.stackMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DoseDiary', style: AppTextStyles.headlineMd()),
                      Text(userName, style: AppTextStyles.bodyLg(color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                      Text(
                        user != null ? userEmail : 'Offline / Guest Mode',
                        style: AppTextStyles.caption(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          const _SectionHeader(title: 'Personalisation'),
          _SettingTile(
            icon: Icons.accessibility_new_rounded,
            label: 'Accessibility',
            subtitle: 'Text size, simple wording',
            onTap: () => context.push(RouteNames.settingsAccessibility),
          ),
          _SettingTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            subtitle: 'Reminders, alerts, sounds',
            onTap: () => context.push(RouteNames.settingsNotifications),
          ),
          _SettingTile(
            icon: Icons.people_rounded,
            label: 'Caregivers',
            subtitle: 'Manage who can view your schedule',
            onTap: () => context.push(RouteNames.caregivers),
          ),

          const _SectionHeader(title: 'Account & Privacy'),
          _SettingTile(
            icon: Icons.account_circle_outlined,
            label: 'Account',
            subtitle: 'Profile, email, password',
            onTap: () => context.push(RouteNames.settingsAccount),
          ),
          _SettingTile(
            icon: Icons.lock_outline,
            label: 'Privacy',
            subtitle: 'Data sharing, notification previews',
            onTap: () => context.push(RouteNames.settingsPrivacy),
          ),

          const _SectionHeader(title: 'Help & Legal'),
          _SettingTile(
            icon: Icons.health_and_safety_outlined,
            label: 'Medical Safety Notice',
            subtitle: 'Important information about this app',
            onTap: () => context.push(RouteNames.settingsSafety),
          ),
          _SettingTile(
            icon: Icons.help_outline,
            label: 'Help & Support',
            subtitle: 'FAQ, contact us',
            onTap: () => context.push(RouteNames.settingsHelp),
          ),
          _SettingTile(
            icon: Icons.notifications_active_outlined,
            label: 'Notification Centre',
            subtitle: 'View all recent alerts',
            onTap: () => context.push(RouteNames.notificationCentre),
          ),

          const _SectionHeader(title: 'Session'),
          _SettingTile(
            icon: Icons.logout,
            label: 'Sign Out',
            subtitle: 'Return to the login screen',
            destructive: true,
            onTap: () async {
              await AuthService.signOut();
              ref.invalidate(todayOccurrencesProvider);
              ref.invalidate(todayMedicationsProvider);
              ref.invalidate(allActiveMedsProvider);
              if (!context.mounted) return;
              context.go(RouteNames.login);
            },
          ),
          const SizedBox(height: AppDimensions.stack2Xl),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.screenMargin,
          AppDimensions.stackXl,
          AppDimensions.screenMargin,
          AppDimensions.stackSm,
        ),
        child: Text(
          title.toUpperCase(),
          style: AppTextStyles.labelMd(color: AppColors.textTertiary),
        ),
      );
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: destructive ? AppColors.error : AppColors.primaryAction),
        title: Text(label, style: AppTextStyles.bodyBold(color: destructive ? AppColors.error : AppColors.textPrimary)),
        subtitle: subtitle != null
            ? Text(subtitle!, style: AppTextStyles.caption())
            : null,
        trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        onTap: onTap,
      );
}
