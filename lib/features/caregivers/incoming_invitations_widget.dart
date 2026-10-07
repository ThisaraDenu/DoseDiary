import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/dd_card.dart';
import '../../core/widgets/dd_loading.dart';
import '../../data/local/models/app_models.dart';
import '../../data/repositories/app_repositories.dart';

/// Caregiver-side incoming invitations component.
/// Displays invitations addressed to the currently logged-in caregiver.
/// Strictly filters by caregiver email, isolating data from other caregivers.
class IncomingCaregiverInvitationsWidget extends ConsumerWidget {
  const IncomingCaregiverInvitationsWidget({
    super.key,
    this.showHeader = true,
    this.hideIfEmpty = false,
  });

  final bool showHeader;
  final bool hideIfEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingAsync = ref.watch(incomingCaregiverInvitationsProvider);

    return incomingAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: DdLoading(),
        ),
      ),
      error: (err, _) => DdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 36),
            const SizedBox(height: 12),
            Text('Could not load incoming invitations',
                style: AppTextStyles.headlineMd()),
            const SizedBox(height: 6),
            Text(
              '$err',
              style: AppTextStyles.caption(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.refresh(incomingCaregiverInvitationsProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAction,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
      data: (invitations) {
        if (invitations.isEmpty) {
          if (hideIfEmpty) return const SizedBox.shrink();
          return DdCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  const Icon(
                    Icons.mark_email_read_outlined,
                    size: 40,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No Incoming Invitations',
                    style: AppTextStyles.headlineMd(),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You do not have any pending or past caregiver invitations addressed to your account.',
                    style:
                        AppTextStyles.caption(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final pendingCount = invitations
            .where((i) => i.status.toLowerCase() == 'pending')
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              Row(
                children: [
                  const Icon(Icons.mail_outline_rounded,
                      size: 20, color: AppColors.primaryAction),
                  const SizedBox(width: 8),
                  Text('Incoming Invitations',
                      style: AppTextStyles.headlineMd()),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.skippedBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingCount Pending',
                        style: AppTextStyles.caption(
                            color: AppColors.skippedForeground),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppDimensions.stackMd),
            ],
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: invitations.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppDimensions.stackMd),
              itemBuilder: (ctx, idx) =>
                  _IncomingInvitationCard(invitation: invitations[idx]),
            ),
          ],
        );
      },
    );
  }
}

class _IncomingInvitationCard extends ConsumerStatefulWidget {
  const _IncomingInvitationCard({required this.invitation});

  final CaregiverInvitation invitation;

  @override
  ConsumerState<_IncomingInvitationCard> createState() =>
      _IncomingInvitationCardState();
}

class _IncomingInvitationCardState
    extends ConsumerState<_IncomingInvitationCard> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final statusLower = widget.invitation.status.toLowerCase();

    final (Color statusColor, Color statusBg, String statusLabel) =
        switch (statusLower) {
      'pending' => (
          AppColors.skippedForeground,
          AppColors.skippedBackground,
          'Pending'
        ),
      'accepted' || 'active' => (
          AppColors.takenForeground,
          AppColors.takenBackground,
          'Accepted'
        ),
      'declined' => (
          AppColors.error,
          AppColors.error.withOpacity(0.12),
          'Declined'
        ),
      'revoked' => (
          AppColors.textTertiary,
          AppColors.textTertiary.withOpacity(0.12),
          'Revoked'
        ),
      _ => (
          AppColors.textTertiary,
          AppColors.borderLight,
          widget.invitation.status
        ),
    };

    final patientName = (widget.invitation.senderName != null &&
            widget.invitation.senderName!.trim().isNotEmpty)
        ? widget.invitation.senderName!.trim()
        : (widget.invitation.patientName != null &&
                widget.invitation.patientName!.trim().isNotEmpty)
            ? widget.invitation.patientName!.trim()
            : (widget.invitation.userId.isNotEmpty
                ? 'Patient ${widget.invitation.userId.length > 6 ? widget.invitation.userId.substring(0, 6) : widget.invitation.userId}'
                : 'Patient');

    return DdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryAction.withOpacity(0.12),
                child: Text(
                  patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                  style:
                      AppTextStyles.headlineMd(color: AppColors.primaryAction),
                ),
              ),
              const SizedBox(width: AppDimensions.stackMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patientName, style: AppTextStyles.bodyBold()),
                    if (widget.invitation.isDirectIdInvitation) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.invitation.senderRole == 'caregiver'
                            ? 'Wants to connect as your caregiver'
                            : 'Wants you to be their caregiver',
                        style: AppTextStyles.caption(
                          color: AppColors.primaryAction,
                        ),
                      ),
                    ],
                    if (widget.invitation.patientEmail != null &&
                        widget.invitation.patientEmail!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.invitation.patientEmail!,
                        style: AppTextStyles.caption(
                            color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (widget.invitation.relationship.isNotEmpty) ...[
                          Text(widget.invitation.relationship,
                              style: AppTextStyles.caption()),
                          Text(' • ',
                              style: AppTextStyles.caption(
                                  color: AppColors.textTertiary)),
                        ],
                        Text(
                          'Invited ${DateFormat('d MMM yyyy').format(widget.invitation.createdAt.toLocal())}',
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
          Text('Requested Permissions', style: AppTextStyles.labelMd()),
          const SizedBox(height: AppDimensions.stackSm),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (widget.invitation.viewSchedule)
                const _PermChip(label: 'Schedule'),
              if (widget.invitation.viewHistory)
                const _PermChip(label: 'History'),
              if (widget.invitation.viewRefills)
                const _PermChip(label: 'Refills'),
              if (widget.invitation.viewAdherence)
                const _PermChip(label: 'Adherence'),
            ],
          ),
          if (statusLower == 'pending') ...[
            const SizedBox(height: AppDimensions.stackLg),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _handleAccept(context, patientName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAction,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Accept'),
                  ),
                ),
                const SizedBox(width: AppDimensions.stackMd),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _handleDecline(context, patientName),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleAccept(BuildContext context, String patientName) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(caregiverRepositoryProvider);
      if (widget.invitation.isDirectIdInvitation) {
        await repo.respondToDirectConnectionInvitation(
          invitationId: widget.invitation.id,
          accept: true,
        );
      } else {
        await repo.acceptIncomingInvitation(widget.invitation.id);
      }
      ref.invalidate(directIncomingInvitationsProvider);
      ref.invalidate(incomingCaregiverInvitationsProvider);
      ref.invalidate(allocatedPatientsProvider);
      ref.invalidate(patientCaregiversListProvider);
      ref.invalidate(patientCaregiversProvider);
      ref.invalidate(caregiverPatientsProvider);
      ref.invalidate(caregiversProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Accepted invitation from $patientName. Connected as caregiver.'),
            backgroundColor: AppColors.takenForeground,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not accept invitation: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleDecline(BuildContext context, String patientName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Invitation'),
        content: Text('Decline the caregiver invitation from $patientName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Decline', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final repo = ref.read(caregiverRepositoryProvider);
        if (widget.invitation.isDirectIdInvitation) {
          await repo.respondToDirectConnectionInvitation(
            invitationId: widget.invitation.id,
            accept: false,
          );
        } else {
          await repo.declineIncomingInvitation(widget.invitation.id);
        }
        ref.invalidate(directIncomingInvitationsProvider);
        ref.invalidate(incomingCaregiverInvitationsProvider);
        ref.invalidate(caregiversProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Declined invitation from $patientName'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not decline invitation: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
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
          color: AppColors.primaryAction.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption(color: AppColors.primaryAction),
        ),
      );
}
