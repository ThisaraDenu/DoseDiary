import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/dd_card.dart';
import '../../core/widgets/dd_button.dart';
import '../../core/widgets/dd_loading.dart';
import '../../core/router/route_names.dart';
import '../../data/local/models/app_models.dart';
import '../../data/remote/auth_service.dart';
import '../../data/remote/supabase_sync_service.dart';
import '../../data/repositories/app_repositories.dart';
import '../home/caregiver_home_view.dart';

// Re-export models and providers for backward compatibility
export '../../data/local/models/app_models.dart'
    show CaregiverInvitation, CaregiverPermission;
export '../../data/repositories/app_repositories.dart'
    show caregiversProvider, incomingCaregiverInvitationsProvider;
export 'incoming_invitations_widget.dart'
    show IncomingCaregiverInvitationsWidget;

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
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 36),
                const SizedBox(height: 12),
                Text('Could not load caregivers',
                    style: AppTextStyles.headlineMd()),
                const SizedBox(height: 6),
                Text('$err',
                    style:
                        AppTextStyles.caption(color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                DdButton(
                  label: 'Try Again',
                  onPressed: () => ref.refresh(caregiversProvider),
                ),
              ],
            ),
          ),
        ),
        data: (caregivers) => RefreshIndicator(
          color: AppColors.primaryAction,
          onRefresh: () async {
            if (AuthService.isLoggedIn) {
              await SupabaseSyncService.pullFromCloud();
            }
            ref.invalidate(caregiversProvider);
            await ref.read(caregiversProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppDimensions.screenMargin),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Privacy notice
              DdCard(
                borderColor: AppColors.info.withOpacity(0.3),
                color: AppColors.info.withOpacity(0.04),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 20, color: AppColors.info),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your Privacy',
                              style: AppTextStyles.bodyBold(
                                  color: AppColors.info)),
                          const SizedBox(height: 4),
                          Text(
                            'You control exactly what caregivers can see. Medication names are never shared — only the information you permit.',
                            style: AppTextStyles.bodyLg(
                                color: AppColors.textSecondary),
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
                  subtitle:
                      'Invite a trusted family member or carer to view your schedule.',
                  actionLabel: 'Invite a Caregiver',
                  onAction: () => context.push(RouteNames.inviteCaregiver),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                        child: Text('Caregivers (${caregivers.length})',
                            style: AppTextStyles.headlineMd())),
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
      ),
      floatingActionButton: caregiversAsync.maybeWhen(
        data: (caregivers) => caregivers.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () => context.push(RouteNames.inviteCaregiver),
                backgroundColor: AppColors.primaryAction,
                icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                label: Text('Invite Caregiver',
                    style: AppTextStyles.labelLg(color: Colors.white)),
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
    final statusLower = cg.status.toLowerCase();
    final statusColor = switch (statusLower) {
      'active' || 'accepted' => AppColors.takenForeground,
      'pending' => AppColors.skippedForeground,
      'declined' => AppColors.error,
      _ => AppColors.textTertiary,
    };

    final statusBg = switch (statusLower) {
      'active' || 'accepted' => AppColors.takenBackground,
      'pending' => AppColors.skippedBackground,
      'declined' => AppColors.error.withOpacity(0.12),
      _ => AppColors.textTertiary.withOpacity(0.12),
    };

    final statusLabel = switch (statusLower) {
      'active' || 'accepted' => 'Accepted',
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
                  style:
                      AppTextStyles.headlineMd(color: AppColors.primaryAction),
                ),
              ),
              const SizedBox(width: AppDimensions.stackMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cg.email, style: AppTextStyles.bodyBold()),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (cg.relationship.isNotEmpty) ...[
                          Text(cg.relationship, style: AppTextStyles.caption()),
                          Text(' • ',
                              style: AppTextStyles.caption(
                                  color: AppColors.textTertiary)),
                        ],
                        Text(
                          'Invited ${DateFormat('d MMM yyyy').format(cg.createdAt.toLocal())}',
                          style: AppTextStyles.caption(
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(statusLabel,
                    style: AppTextStyles.statusBadge(color: statusColor)),
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
              if (statusLower == 'accepted' || statusLower == 'active') ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleEdit(context, ref),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Edit Access'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryAction,
                      side: const BorderSide(color: AppColors.primaryAction),
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleAction(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        statusLower == 'declined' || statusLower == 'revoked'
                            ? AppColors.textSecondary
                            : AppColors.error,
                    side: BorderSide(
                      color:
                          statusLower == 'declined' || statusLower == 'revoked'
                              ? AppColors.borderMedium
                              : AppColors.error,
                    ),
                    minimumSize: const Size(0, 44),
                  ),
                  child: Text(
                    switch (statusLower) {
                      'pending' => 'Cancel Invitation',
                      'accepted' || 'active' => 'Revoke Access',
                      _ => 'Remove',
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleEdit(BuildContext context, WidgetRef ref) async {
    final relCtrl = TextEditingController(text: cg.relationship);
    bool viewSchedule = cg.viewSchedule;
    bool viewHistory = cg.viewHistory;
    bool viewRefills = cg.viewRefills;
    bool viewAdherence = cg.viewAdherence;

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E2E2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.tune_rounded,
                        color: AppColors.primaryAction, size: 22),
                    const SizedBox(width: 8),
                    Text('Edit Caregiver Access',
                        style: AppTextStyles.headlineMd()),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Manage permissions and relationship for ${cg.email}',
                    style:
                        AppTextStyles.caption(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                Text('Relationship', style: AppTextStyles.bodyBold()),
                const SizedBox(height: 6),
                TextField(
                  controller: relCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Daughter, Nurse, Brother',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Permissions', style: AppTextStyles.labelMd()),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Daily schedule'),
                  value: viewSchedule,
                  onChanged: (v) => setSheetState(() => viewSchedule = v),
                  activeColor: AppColors.primaryAction,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Dose history'),
                  value: viewHistory,
                  onChanged: (v) => setSheetState(() => viewHistory = v),
                  activeColor: AppColors.primaryAction,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Adherence reports'),
                  value: viewAdherence,
                  onChanged: (v) => setSheetState(() => viewAdherence = v),
                  activeColor: AppColors.primaryAction,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Refill reminders'),
                  value: viewRefills,
                  onChanged: (v) => setSheetState(() => viewRefills = v),
                  activeColor: AppColors.primaryAction,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: DdButton(
                    label: 'Save Changes',
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (updated == true) {
      await ref
          .read(caregiverRepositoryProvider)
          .updateCaregiverRelationshipAndPermissions(
            invitationId: cg.id,
            relationship: relCtrl.text.trim(),
            viewSchedule: viewSchedule,
            viewHistory: viewHistory,
            viewRefills: viewRefills,
            viewAdherence: viewAdherence,
          );
      ref.invalidate(caregiversProvider);
      ref.invalidate(patientCaregiversListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated access for ${cg.email}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref) async {
    final statusLower = cg.status.toLowerCase();
    if (statusLower == 'pending') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancel Invitation'),
          content: Text('Cancel the pending invitation to ${cg.email}?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel Invitation',
                  style: TextStyle(color: AppColors.error)),
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
              content: Text('Invitation to ${cg.email} cancelled'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else if (statusLower == 'accepted' || statusLower == 'active') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Revoke Access'),
          content: Text(
              'Remove ${cg.email}\'s caregiver access? They will no longer receive alerts.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Revoke',
                  style: TextStyle(color: AppColors.error)),
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
              content: Text('Caregiver access revoked for ${cg.email}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      // Declined or revoked
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove Record'),
          content: Text('Remove this invitation record for ${cg.email}?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove',
                  style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await ref.read(caregiverRepositoryProvider).deleteInvitation(cg.id);
        ref.invalidate(caregiversProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed record for ${cg.email}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
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
        child: Text(label,
            style: AppTextStyles.caption(color: AppColors.takenForeground)),
      );
}

// ── Other caregiver screens ───────────────────────────────────────────────────

class InviteCaregiverScreen extends ConsumerStatefulWidget {
  const InviteCaregiverScreen({super.key});

  @override
  ConsumerState<InviteCaregiverScreen> createState() =>
      _InviteCaregiverScreenState();
}

class _InviteCaregiverScreenState extends ConsumerState<InviteCaregiverScreen> {
  final _publicIdCtrl = TextEditingController();
  final _relationshipCtrl = TextEditingController();
  String _senderRole = 'patient';
  bool _isLoading = false;

  @override
  void dispose() {
    _publicIdCtrl.dispose();
    _relationshipCtrl.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final publicId = _publicIdCtrl.text.trim();
    final relationship = _relationshipCtrl.text.trim().isEmpty
        ? 'Family member'
        : _relationshipCtrl.text.trim();

    final repo = ref.read(caregiverRepositoryProvider);

    setState(() => _isLoading = true);

    try {
      await repo.createDirectConnectionInvitation(
        publicId: publicId,
        senderRole: _senderRole,
        relationship: relationship,
      );

      // Refresh list in CaregiverManagementScreen
      ref.invalidate(caregiversProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF97F5CC), size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Invitation sent to $publicId')),
            ],
          ),
          backgroundColor: const Color(0xFF303030),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e
              .toString()
              .replaceAll('ArgumentError: ', '')
              .replaceAll('Invalid argument(s): ', '')
              .replaceAll('Exception: ', '')),
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
      appBar: AppBar(title: const Text('Connect with a user')),
      backgroundColor: AppColors.scaffoldBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connect by DoseDiary ID', style: AppTextStyles.headlineLg()),
            const SizedBox(height: AppDimensions.stackSm),
            Text(
              'Enter the unique ID shown in the other user’s Settings. They will receive an in-app invitation to accept or decline.',
              style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.stackXl),

            Text('I am connecting as', style: AppTextStyles.bodyBold()),
            const SizedBox(height: AppDimensions.stackSm),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'patient',
                  label: Text('Patient'),
                  icon: Icon(Icons.medication_outlined),
                ),
                ButtonSegment(
                  value: 'caregiver',
                  label: Text('Caregiver'),
                  icon: Icon(Icons.health_and_safety_outlined),
                ),
              ],
              selected: {_senderRole},
              onSelectionChanged: (selection) {
                setState(() => _senderRole = selection.first);
              },
            ),
            const SizedBox(height: AppDimensions.stackLg),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _senderRole == 'patient' ? 'Caregiver ID' : 'Patient ID',
                  style: AppTextStyles.bodyBold(),
                ),
                const SizedBox(height: AppDimensions.stackSm),
                TextFormField(
                  controller: _publicIdCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    hintText: '#12345',
                    counterText: '',
                  ),
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
                  decoration: const InputDecoration(
                      hintText: 'e.g. Daughter, Son, Nurse'),
                  style: AppTextStyles.bodyXl(),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.stackXl),

            const SizedBox(height: AppDimensions.stackLg),
            DdButton(
                label: 'Send Invitation',
                onPressed: _invite,
                isLoading: _isLoading),
          ],
        ),
      ),
    );
  }
}

class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  State<CaregiverDashboardScreen> createState() =>
      _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends State<CaregiverDashboardScreen> {
  void _showToast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF97F5CC), size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message, style: const TextStyle(fontSize: 13.5))),
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
              Icon(Icons.volunteer_activism_rounded,
                  color: Color(0xFFB1002C), size: 22),
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
