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
import '../../data/local/models/app_models.dart';
import '../../data/repositories/app_repositories.dart';
import '../home/caregiver_home_view.dart';

// Re-export models and providers for backward compatibility
export '../../data/local/models/app_models.dart' show CaregiverInvitation, CaregiverPermission;
export '../../data/repositories/app_repositories.dart' show caregiversProvider;

// Screen
class CaregiverManagementScreen extends ConsumerWidget {
  const CaregiverManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caregiversAsync = ref.watch(caregiversProvider);

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
      body: caregiversAsync.when(
        loading: () => const DdLoading(),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.screenMargin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
                const SizedBox(height: 12),
                Text('Could not load caregivers', style: AppTextStyles.headlineMd()),
                const SizedBox(height: 6),
                Text('$err', style: AppTextStyles.caption(color: AppColors.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                DdButton(
                  label: 'Try Again',
                  onPressed: () => ref.refresh(caregiversProvider),
                ),
              ],
            ),
          ),
        ),
        data: (caregivers) => ListView(
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
      ),
      floatingActionButton: caregiversAsync.maybeWhen(
        data: (caregivers) => caregivers.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () => context.push(RouteNames.inviteCaregiver),
                backgroundColor: AppColors.primaryAction,
                icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                label: Text('Invite Caregiver', style: AppTextStyles.labelLg(color: Colors.white)),
              )
            : null,
        orElse: () => null,
      ),
    );
  }
}

class _CaregiverCard extends ConsumerWidget {
  const _CaregiverCard({required this.cg});
  final CaregiverInvitation cg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = switch (cg.status) {
      'active' || 'accepted' => AppColors.takenForeground,
      'pending' => AppColors.skippedForeground,
      'declined' => AppColors.error,
      _ => AppColors.textTertiary,
    };

    final statusLabel = switch (cg.status) {
      'active' || 'accepted' => 'Active',
      'pending' => 'Pending',
      'declined' => 'Declined',
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
                  cg.email.isNotEmpty ? cg.email[0].toUpperCase() : '?',
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
          if (cg.status != 'revoked') ...[
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
                    child: Text(cg.status == 'pending' ? 'Cancel Invitation' : 'Revoke Access'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final isPending = cg.status == 'pending';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isPending ? 'Cancel Invitation' : 'Revoke Access'),
        content: Text(
          isPending
              ? 'Cancel the pending invitation to ${cg.email}?'
              : 'Remove ${cg.email}\'s caregiver access? They will no longer receive alerts.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isPending ? 'Cancel Invitation' : 'Revoke',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(caregiverRepositoryProvider).revokeInvitation(cg.id);
      ref.invalidate(caregiversProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPending ? 'Invitation to ${cg.email} cancelled' : 'Caregiver access revoked for ${cg.email}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

// ── Other caregiver screens ───────────────────────────────────────────────────

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
    final email = _emailCtrl.text.trim();
    final relationship = _relationshipCtrl.text.trim().isEmpty ? 'Family member' : _relationshipCtrl.text.trim();

    final repo = ref.read(caregiverRepositoryProvider);

    // Validate inputs
    final validationError = await repo.validateInvitation(caregiverEmail: email);
    if (validationError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await repo.createInvitation(
        caregiverEmail: email,
        relationship: relationship,
        viewSchedule: _viewSchedule,
        viewHistory: _viewHistory,
        viewRefills: _viewRefills,
        viewAdherence: _viewAdherence,
      );

      // Refresh list in CaregiverManagementScreen
      ref.invalidate(caregiversProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF97F5CC), size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Invitation sent to $email')),
            ],
          ),
          backgroundColor: const Color(0xFF303030),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('ArgumentError: ', '').replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  State<CaregiverDashboardScreen> createState() => _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends State<CaregiverDashboardScreen> {
  void _showToast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF97F5CC), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13.5))),
          ],
        ),
        backgroundColor: const Color(0xFF303030),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.volunteer_activism_rounded, color: Color(0xFFB1002C), size: 22),
              SizedBox(width: 8),
              Text('Caregiver Dashboard'),
            ],
          ),
          backgroundColor: const Color(0xFFF9F9F9),
          elevation: 0,
        ),
        backgroundColor: const Color(0xFFF9F9F9),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
          child: CaregiverHomeView(
            userName: 'Ishara',
            onShowToast: _showToast,
          ),
        ),
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
