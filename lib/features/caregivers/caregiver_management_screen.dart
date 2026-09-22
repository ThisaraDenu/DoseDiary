import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/dd_card.dart';
import '../../core/widgets/dd_button.dart';
import '../../core/widgets/dd_loading.dart';
import '../../core/router/route_names.dart';

// Caregiver model
class CaregiverInvitation {
  const CaregiverInvitation({
    required this.id,
    required this.email,
    required this.relationship,
    required this.status,
    required this.createdAt,
    this.viewSchedule = true,
    this.viewHistory = true,
    this.viewRefills = false,
    this.viewAdherence = true,
  });

  final String id;
  final String email;
  final String relationship;
  final String status; // pending | active | revoked
  final DateTime createdAt;
  final bool viewSchedule;
  final bool viewHistory;
  final bool viewRefills;
  final bool viewAdherence;
}

// Provider (demo state)
final caregiversProvider = StateProvider<List<CaregiverInvitation>>((ref) => [
  CaregiverInvitation(
    id: 'cg-001',
    email: 'family@example.com',
    relationship: 'Daughter',
    status: 'active',
    createdAt: DateTime.now().subtract(const Duration(days: 7)),
    viewSchedule: true,
    viewHistory: true,
    viewRefills: true,
    viewAdherence: true,
  ),
]);

// Screen
class CaregiverManagementScreen extends ConsumerWidget {
  const CaregiverManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caregivers = ref.watch(caregiversProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Caregivers'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () => context.push(RouteNames.caregiverDashboard),
            icon: const Icon(Icons.dashboard_outlined, size: 18),
            label: const Text('Dashboard'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.screenMargin),
        children: [
          // Privacy notice
          DdCard(
            borderColor: AppColors.info.withOpacity(0.3),
            color: AppColors.info.withOpacity(0.04),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, size: 20, color: AppColors.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Privacy', style: AppTextStyles.bodyBold(color: AppColors.info)),
                      const SizedBox(height: 4),
                      Text(
                        'You control exactly what caregivers can see. Medication names are never shared — only the information you permit.',
                        style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.stackXl),

          if (caregivers.isEmpty) ...[
            DdEmptyState(
              icon: Icons.people_outline,
              title: 'No caregivers added',
              subtitle: 'Invite a trusted family member or carer to view your schedule.',
              actionLabel: 'Invite a Caregiver',
              onAction: () => context.push(RouteNames.inviteCaregiver),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(child: Text('Caregivers (${caregivers.length})', style: AppTextStyles.headlineMd())),
                TextButton.icon(
                  onPressed: () => context.push(RouteNames.inviteCaregiver),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Invite'),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.stackMd),
            for (final cg in caregivers) ...[
              _CaregiverCard(cg: cg),
              const SizedBox(height: AppDimensions.stackMd),
            ],
          ],
        ],
      ),
      floatingActionButton: caregivers.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => context.push(RouteNames.inviteCaregiver),
              backgroundColor: AppColors.primaryAction,
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              label: Text('Invite Caregiver', style: AppTextStyles.labelLg(color: Colors.white)),
            )
          : null,
    );
  }
}

class _CaregiverCard extends ConsumerWidget {
  const _CaregiverCard({required this.cg});
  final CaregiverInvitation cg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = switch (cg.status) {
      'active' => AppColors.takenForeground,
      'pending' => AppColors.skippedForeground,
      _ => AppColors.textTertiary,
    };

    final statusLabel = switch (cg.status) {
      'active' => 'Active',
      'pending' => 'Invited',
      _ => 'Revoked',
    };

    return DdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryAction.withOpacity(0.1),
                child: Text(
                  cg.email[0].toUpperCase(),
                  style: AppTextStyles.headlineMd(color: AppColors.primaryAction),
                ),
              ),
              const SizedBox(width: AppDimensions.stackMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cg.email, style: AppTextStyles.bodyBold()),
                    Text(cg.relationship, style: AppTextStyles.caption()),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(statusLabel, style: AppTextStyles.statusBadge(color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.stackMd),
          const Divider(),
          const SizedBox(height: AppDimensions.stackSm),
          Text('Permissions', style: AppTextStyles.labelMd()),
          const SizedBox(height: AppDimensions.stackSm),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (cg.viewSchedule) const _PermChip(label: 'Schedule'),
              if (cg.viewHistory) const _PermChip(label: 'History'),
              if (cg.viewRefills) const _PermChip(label: 'Refills'),
              if (cg.viewAdherence) const _PermChip(label: 'Adherence'),
            ],
          ),
          const SizedBox(height: AppDimensions.stackLg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _revoke(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text('Revoke Access'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Access'),
        content: Text('Remove ${cg.email}\'s caregiver access? They will no longer receive alerts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(caregiversProvider.notifier).update(
            (list) => list.where((c) => c.id != cg.id).toList(),
          );
    }
  }
}

class _PermChip extends StatelessWidget {
  const _PermChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.takenBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: AppTextStyles.caption(color: AppColors.takenForeground)),
      );
}

// ── Other caregiver screens (stubs with content) ──────────────────────────────

class InviteCaregiverScreen extends ConsumerStatefulWidget {
  const InviteCaregiverScreen({super.key});

  @override
  ConsumerState<InviteCaregiverScreen> createState() => _InviteCaregiverScreenState();
}

class _InviteCaregiverScreenState extends ConsumerState<InviteCaregiverScreen> {
  final _emailCtrl = TextEditingController();
  final _relationshipCtrl = TextEditingController();
  bool _viewSchedule = true;
  bool _viewHistory = true;
  bool _viewRefills = false;
  bool _viewAdherence = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _relationshipCtrl.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    if (_emailCtrl.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    final newCg = CaregiverInvitation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      email: _emailCtrl.text.trim(),
      relationship: _relationshipCtrl.text.trim().isEmpty ? 'Family member' : _relationshipCtrl.text.trim(),
      status: 'pending',
      createdAt: DateTime.now(),
      viewSchedule: _viewSchedule,
      viewHistory: _viewHistory,
      viewRefills: _viewRefills,
      viewAdherence: _viewAdherence,
    );

    ref.read(caregiversProvider.notifier).update((list) => [...list, newCg]);

    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invitation sent to ${_emailCtrl.text.trim()}')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite Caregiver')),
      backgroundColor: AppColors.scaffoldBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invite by email', style: AppTextStyles.headlineLg()),
            const SizedBox(height: AppDimensions.stackSm),
            Text(
              'Your caregiver will receive an email with a link to create a free DoseDiary account.',
              style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.stackXl),

            // Email
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email address', style: AppTextStyles.bodyBold()),
                const SizedBox(height: AppDimensions.stackSm),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'caregiver@example.com'),
                  style: AppTextStyles.bodyXl(),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.stackLg),

            // Relationship
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Relationship', style: AppTextStyles.bodyBold()),
                const SizedBox(height: AppDimensions.stackSm),
                TextFormField(
                  controller: _relationshipCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. Daughter, Son, Nurse'),
                  style: AppTextStyles.bodyXl(),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.stackXl),

            Text('Permissions', style: AppTextStyles.headlineMd()),
            const SizedBox(height: AppDimensions.stackSm),
            Text(
              'Choose what your caregiver can see.',
              style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.stackMd),

            _PermissionToggle(label: 'Daily schedule', value: _viewSchedule, onChanged: (v) => setState(() => _viewSchedule = v)),
            _PermissionToggle(label: 'Dose history', value: _viewHistory, onChanged: (v) => setState(() => _viewHistory = v)),
            _PermissionToggle(label: 'Adherence reports', value: _viewAdherence, onChanged: (v) => setState(() => _viewAdherence = v)),
            _PermissionToggle(label: 'Refill reminders', value: _viewRefills, onChanged: (v) => setState(() => _viewRefills = v)),

            const SizedBox(height: AppDimensions.stackXl),
            DdButton(label: 'Send Invitation', onPressed: _invite, isLoading: _isLoading),
          ],
        ),
      ),
    );
  }
}

class _PermissionToggle extends StatelessWidget {
  const _PermissionToggle({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        title: Text(label, style: AppTextStyles.bodyXl()),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryAction,
        contentPadding: EdgeInsets.zero,
      );
}

class CaregiverDashboardScreen extends StatelessWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Caregiver Dashboard')),
        backgroundColor: AppColors.scaffoldBackground,
        body: const Center(child: Text('Caregiver dashboard — view-only mode')),
      );
}

class CaregiverAlertScreen extends StatelessWidget {
  const CaregiverAlertScreen({super.key, required this.alertId});
  final String alertId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Alert')),
        backgroundColor: AppColors.scaffoldBackground,
        body: Center(child: Text('Alert details — ID: $alertId')),
      );
}
