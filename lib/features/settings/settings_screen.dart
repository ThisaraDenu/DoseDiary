import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/dd_logo.dart';
import '../../core/router/route_names.dart';
import '../../data/local/database_provider.dart';
import '../../data/remote/auth_service.dart';
import '../home/home_dashboard_screen.dart';
import 'settings_providers.dart';

final userPublicIdProvider = FutureProvider<String?>((ref) async {
  ref.watch(accountSessionEpochProvider);
  return AuthService.ensurePublicId();
});

String _languageName(String code) => switch (code) {
      'si' => 'Sinhala',
      'ta' => 'Tamil',
      _ => 'English',
    };

Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Sign out of DoseDiary?'),
          content: const Text(
            'Your synchronized account data will remain in the cloud. Local account data on this device will be cleared.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ) ??
      false;
  if (!confirmed) return;
  await AuthService.signOut();
  ref.read(accountSessionEpochProvider.notifier).state++;
  if (!context.mounted) return;
  context.go(RouteNames.login);
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = AuthService.currentUser;
    final settings = ref.watch(settingsProvider);
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
          Material(
            color: AppColors.cardSurface,
            child: InkWell(
              onTap: () => context.push(RouteNames.settingsAccount),
              child: Padding(
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
                          Text(userName,
                              style: AppTextStyles.bodyLg(
                                  color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis),
                          ref.watch(userAgeProvider).when(
                                data: (age) => ref
                                    .watch(userGenderProvider)
                                    .when(
                                      data: (gender) => ref
                                          .watch(userPhoneProvider)
                                          .when(
                                            data: (phone) {
                                              final parts = <String>[];
                                              if (age != null) {
                                                parts.add('$age yrs');
                                              }
                                              if (gender != null &&
                                                  gender.isNotEmpty) {
                                                parts.add(gender);
                                              }
                                              if (phone != null &&
                                                  phone.isNotEmpty) {
                                                parts.add(phone);
                                              }
                                              if (parts.isEmpty) {
                                                return const SizedBox.shrink();
                                              }
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2, bottom: 2),
                                                child: Text(
                                                  parts.join(' • '),
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.primaryAction,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              );
                                            },
                                            loading: () =>
                                                const SizedBox.shrink(),
                                            error: (_, __) =>
                                                const SizedBox.shrink(),
                                          ),
                                      loading: () => const SizedBox.shrink(),
                                      error: (_, __) => const SizedBox.shrink(),
                                    ),
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                          Text(
                            user != null ? userEmail : 'Offline / Guest Mode',
                            style: AppTextStyles.caption(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          const _PublicIdCard(),
          const _SectionHeader(title: 'Medication & Tracking'),
          _SettingsGroup(
            children: [
              _SettingTile(
                icon: Icons.medication_outlined,
                label: 'My medications',
                subtitle: 'Schedules, doses, stock, and prescription details',
                onTap: () => context.push(RouteNames.medications),
              ),
              _SettingTile(
                icon: Icons.history_rounded,
                label: 'Medication history',
                subtitle: 'Dose records, weekly charts, and PDF downloads',
                onTap: () => context.push(RouteNames.history),
              ),
              _SettingTile(
                icon: Icons.insights_outlined,
                label: 'Adherence insights',
                subtitle: 'Review medication-taking patterns',
                onTap: () => context.push(RouteNames.adherence),
              ),
              _SettingTile(
                icon: Icons.inventory_2_outlined,
                label: 'Refills & stock',
                subtitle: 'Inventory levels and refill reminders',
                onTap: () => context.push(RouteNames.refills),
              ),
            ],
          ),
          const _SectionHeader(title: 'Care Network'),
          _SettingsGroup(
            children: [
              _SettingTile(
                icon: Icons.people_alt_outlined,
                label: 'Caregivers & patients',
                subtitle: 'Connections, invitations, and access permissions',
                onTap: () => context.push(RouteNames.caregivers),
              ),
              _SettingTile(
                icon: Icons.notifications_active_outlined,
                label: 'Notification centre',
                subtitle: 'Recent reminders and caregiver alerts',
                onTap: () => context.push(RouteNames.notificationCentre),
              ),
            ],
          ),
          const _SectionHeader(title: 'Preferences'),
          _SettingsGroup(
            children: [
              _SettingTile(
                icon: Icons.notifications_outlined,
                label: 'Reminders & notifications',
                subtitle: 'Sound, vibration, retries, and grace period',
                trailingText:
                    settings.notificationRemindersEnabled ? 'On' : 'Off',
                onTap: () => context.push(RouteNames.settingsNotifications),
              ),
              _SettingTile(
                icon: Icons.accessibility_new_rounded,
                label: 'Accessibility & language',
                subtitle: 'Text size, simpler wording, and language',
                trailingText: _languageName(settings.locale.languageCode),
                onTap: () => context.push(RouteNames.settingsAccessibility),
              ),
              _SettingTile(
                icon: Icons.admin_panel_settings_outlined,
                label: 'App permissions',
                subtitle: 'Manage device access used by DoseDiary',
                onTap: () => context.push(RouteNames.permissions),
              ),
            ],
          ),
          const _SectionHeader(title: 'Data & Security'),
          _SettingsGroup(
            children: [
              _SettingTile(
                icon: Icons.account_circle_outlined,
                label: 'Profile & account',
                subtitle: 'Photo, phone, birthday, gender, and email',
                onTap: () => context.push(RouteNames.settingsAccount),
              ),
              _SettingTile(
                icon: Icons.sync_rounded,
                label: 'Data & sync',
                subtitle: 'Cloud sync, local records, and PDF exports',
                trailingText: user == null ? 'Local' : 'Connected',
                onTap: () => context.push(RouteNames.settingsDataSync),
              ),
              _SettingTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy',
                subtitle: 'Notification previews and data storage',
                trailingText:
                    settings.privacySafePreviews ? 'Protected' : 'Detailed',
                onTap: () => context.push(RouteNames.settingsPrivacy),
              ),
              _SettingTile(
                icon: Icons.shield_outlined,
                label: 'Security & permissions',
                subtitle: 'Password, device access, and preference reset',
                onTap: () => context.push(RouteNames.settingsSecurity),
              ),
            ],
          ),
          const _SectionHeader(title: 'Help & Information'),
          _SettingsGroup(
            children: [
              _SettingTile(
                icon: Icons.help_outline_rounded,
                label: 'Help & support',
                subtitle: 'Answers to common DoseDiary questions',
                onTap: () => context.push(RouteNames.settingsHelp),
              ),
              _SettingTile(
                icon: Icons.health_and_safety_outlined,
                label: 'Medical safety notice',
                subtitle: 'Important information about using this app',
                onTap: () => context.push(RouteNames.settingsSafety),
              ),
              _SettingTile(
                icon: Icons.info_outline_rounded,
                label: 'About DoseDiary',
                subtitle: 'Version, licences, and app information',
                onTap: () => context.push(RouteNames.settingsAbout),
              ),
            ],
          ),
          const _SectionHeader(title: 'Session'),
          _SettingsGroup(
            children: [
              _SettingTile(
                icon: Icons.logout_rounded,
                label: 'Sign out',
                subtitle:
                    'Securely clear local account data and return to login',
                destructive: true,
                onTap: () => _confirmSignOut(context, ref),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.stack2Xl),
        ],
      ),
    );
  }
}

class _PublicIdCard extends ConsumerWidget {
  const _PublicIdCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publicId = ref.watch(userPublicIdProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.screenMargin,
        AppDimensions.stackLg,
        AppDimensions.screenMargin,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.primaryAction.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(
            color: AppColors.primaryAction.withOpacity(0.22),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryAction.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.tag_rounded,
                color: AppColors.primaryAction,
              ),
            ),
            const SizedBox(width: AppDimensions.stackMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your DoseDiary ID', style: AppTextStyles.bodyBold()),
                  const SizedBox(height: 3),
                  publicId.when(
                    data: (id) => Text(
                      id ?? 'ID unavailable',
                      style: AppTextStyles.headlineMd(
                        color: AppColors.primaryAction,
                      ),
                    ),
                    loading: () => const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => Text(
                      'ID unavailable',
                      style: AppTextStyles.bodyLg(color: AppColors.error),
                    ),
                  ),
                  Text(
                    'Share this ID to connect with a patient or caregiver.',
                    style: AppTextStyles.caption(),
                  ),
                ],
              ),
            ),
            if (publicId.valueOrNull != null)
              IconButton(
                tooltip: 'Copy ID',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: publicId.valueOrNull!),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('DoseDiary ID copied')),
                  );
                },
              )
            else if (!publicId.isLoading)
              IconButton(
                tooltip: 'Retry ID',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => ref.invalidate(userPublicIdProvider),
              ),
          ],
        ),
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

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppDimensions.screenMargin),
        child: Material(
          color: AppColors.cardSurface,
          elevation: 1,
          shadowColor: Colors.black.withOpacity(0.08),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            side: const BorderSide(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1)
                  const Divider(height: 1, indent: 64),
              ],
            ],
          ),
        ),
      );
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.trailingText,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon,
            color: destructive ? AppColors.error : AppColors.primaryAction),
        title: Text(label,
            style: AppTextStyles.bodyBold(
                color: destructive ? AppColors.error : AppColors.textPrimary)),
        subtitle: subtitle != null
            ? Text(subtitle!, style: AppTextStyles.caption())
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 78),
                child: Text(
                  trailingText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(
                    color:
                        destructive ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
        onTap: onTap,
      );
}
