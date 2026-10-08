import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/dd_card.dart';
import '../../data/local/database_provider.dart';
import '../../data/remote/auth_service.dart';
import '../../data/remote/supabase_sync_service.dart';
import '../../main.dart';
import 'settings_providers.dart';

class SettingsDataSummary {
  const SettingsDataSummary({required this.medications, required this.doses});

  final int medications;
  final int doses;
}

final settingsDataSummaryProvider =
    FutureProvider<SettingsDataSummary>((ref) async {
  ref.watch(accountSessionEpochProvider);
  final userId = AuthService.currentUser?.id;
  if (userId == null) {
    return const SettingsDataSummary(medications: 0, doses: 0);
  }
  final db = await ref.watch(appDatabaseProvider).database;
  final medicationResult = await db.rawQuery(
    'SELECT COUNT(*) AS count FROM medications WHERE user_id = ?',
    [userId],
  );
  final doseResult = await db.rawQuery(
    'SELECT COUNT(*) AS count FROM dose_occurrences WHERE user_id = ?',
    [userId],
  );
  return SettingsDataSummary(
    medications: (medicationResult.first['count'] as num?)?.toInt() ?? 0,
    doses: (doseResult.first['count'] as num?)?.toInt() ?? 0,
  );
});

class DataSyncSettingsScreen extends ConsumerStatefulWidget {
  const DataSyncSettingsScreen({super.key});

  @override
  ConsumerState<DataSyncSettingsScreen> createState() =>
      _DataSyncSettingsScreenState();
}

class _DataSyncSettingsScreenState
    extends ConsumerState<DataSyncSettingsScreen> {
  bool _syncing = false;
  DateTime? _lastSync;

  String get _lastSyncKey =>
      'settings.${AuthService.currentUser?.id ?? 'guest'}.last_sync';

  @override
  void initState() {
    super.initState();
    final value = ref.read(sharedPreferencesProvider).getString(_lastSyncKey);
    _lastSync = value == null ? null : DateTime.tryParse(value);
  }

  Future<void> _syncNow() async {
    if (!AuthService.isLoggedIn || _syncing) return;
    setState(() => _syncing = true);
    try {
      await SupabaseSyncService.syncAll();
      final now = DateTime.now();
      await ref
          .read(sharedPreferencesProvider)
          .setString(_lastSyncKey, now.toIso8601String());
      ref.invalidate(settingsDataSummaryProvider);
      if (!mounted) return;
      setState(() {
        _lastSync = now;
        _syncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medication data synced successfully.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync failed. Check your connection.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(settingsDataSummaryProvider);
    final signedIn = AuthService.isLoggedIn;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(title: const Text('Data & Sync')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          DdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailHeading(
                  icon: signedIn
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  title:
                      signedIn ? 'Cloud sync connected' : 'Local device only',
                  color: signedIn
                      ? const Color(0xFF14735C)
                      : AppColors.textSecondary,
                ),
                const SizedBox(height: 10),
                Text(
                  signedIn
                      ? 'Your local medication records can be synchronized with your DoseDiary account.'
                      : 'Sign in to back up and synchronize your medication records.',
                  style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
                ),
                if (_lastSync != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last synced ${DateFormat('d MMM yyyy, h:mm a').format(_lastSync!)}',
                    style: AppTextStyles.caption(),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: signedIn && !_syncing ? _syncNow : null,
                    icon: _syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(_syncing ? 'Syncing...' : 'Sync now'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DdCard(
            child: summary.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Local data summary unavailable.'),
              data: (value) => Row(
                children: [
                  Expanded(
                      child: _DataMetric(
                          value: '${value.medications}', label: 'Medications')),
                  const SizedBox(height: 46, child: VerticalDivider()),
                  Expanded(
                      child: _DataMetric(
                          value: '${value.doses}', label: 'Dose records')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _DetailGroup(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined,
                      color: AppColors.primaryAction),
                  title: const Text('Download medication history'),
                  subtitle: const Text('Create daily or weekly PDF records'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(RouteNames.history),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined,
                      color: AppColors.primaryAction),
                  title: const Text('Profile & account data'),
                  subtitle: const Text(
                      'Review the personal details linked to this account'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(RouteNames.settingsAccount),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'DoseDiary keeps an offline copy on this device so medication information remains available without a connection.',
            style: AppTextStyles.caption(),
          ),
        ],
      ),
    );
  }
}

class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  Future<void> _sendResetLink(BuildContext context) async {
    final email = AuthService.currentUser?.email;
    if (email == null || email.isEmpty) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Reset password?'),
            content:
                Text('A secure password reset link will be sent to $email.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Send link'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await AuthService.sendPasswordResetEmail(email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not send the reset link. Try again.')),
      );
    }
  }

  Future<void> _resetPreferences(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Reset app preferences?'),
            content: const Text(
              'Text size, language, notification, and privacy preferences will return to their defaults. Medication data will not be deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Reset'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(settingsProvider.notifier).resetToDefaults();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App preferences reset to defaults.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final email = AuthService.currentUser?.email;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(title: const Text('Security & Permissions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          DdCard(
            child: _DetailHeading(
              icon: Icons.verified_user_outlined,
              title: AuthService.isLoggedIn
                  ? 'Signed-in account protected'
                  : 'Offline session',
              color: const Color(0xFF14735C),
            ),
          ),
          const SizedBox(height: 14),
          _DetailGroup(
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.privacySafePreviews,
                  activeColor: AppColors.primaryAction,
                  secondary: const Icon(Icons.visibility_off_outlined,
                      color: AppColors.primaryAction),
                  title: const Text('Private notification previews'),
                  subtitle:
                      const Text('Hide medication names on the lock screen'),
                  onChanged: (value) => ref
                      .read(settingsProvider.notifier)
                      .setPrivacySafePreviews(value),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined,
                      color: AppColors.primaryAction),
                  title: const Text('App permissions'),
                  subtitle:
                      const Text('Notifications, camera, contacts, and more'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(RouteNames.permissions),
                ),
                if (email != null) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.password_rounded,
                        color: AppColors.primaryAction),
                    title: const Text('Reset password'),
                    subtitle: Text(email),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _sendResetLink(context),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _DetailGroup(
            child: ListTile(
              leading: const Icon(Icons.restart_alt_rounded,
                  color: AppColors.primaryAction),
              title: const Text('Reset app preferences'),
              subtitle: const Text(
                  'Keep medication data and restore default settings'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _resetPreferences(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

class AboutSettingsScreen extends StatelessWidget {
  const AboutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(title: const Text('About DoseDiary')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          DdCard(
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE8EE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medical_services_rounded,
                      size: 34, color: AppColors.primaryAction),
                ),
                const SizedBox(height: 12),
                Text('DoseDiary', style: AppTextStyles.headlineMd()),
                const SizedBox(height: 4),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final info = snapshot.data;
                    return Text(
                      info == null
                          ? 'Medication reminder and adherence tracker'
                          : 'Version ${info.version} (${info.buildNumber})',
                      style: AppTextStyles.caption(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _DetailGroup(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.health_and_safety_outlined,
                      color: AppColors.primaryAction),
                  title: const Text('Medical safety notice'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(RouteNames.settingsSafety),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded,
                      color: AppColors.primaryAction),
                  title: const Text('Help & support'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(RouteNames.settingsHelp),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.description_outlined,
                      color: AppColors.primaryAction),
                  title: const Text('Open-source licences'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'DoseDiary',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'DoseDiary is a reminder and record-keeping tool. It does not diagnose conditions, recommend doses, or replace advice from a qualified healthcare professional.',
            style: AppTextStyles.caption(),
          ),
        ],
      ),
    );
  }
}

class _DetailHeading extends StatelessWidget {
  const _DetailHeading(
      {required this.icon, required this.title, required this.color});

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title, style: AppTextStyles.bodyBold(color: color))),
        ],
      );
}

class _DetailGroup extends StatelessWidget {
  const _DetailGroup({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.cardSurface,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.08),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        child: child,
      );
}

class _DataMetric extends StatelessWidget {
  const _DataMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: AppTextStyles.headlineMd(color: AppColors.primaryAction)),
          const SizedBox(height: 3),
          Text(label, style: AppTextStyles.caption()),
        ],
      );
}
