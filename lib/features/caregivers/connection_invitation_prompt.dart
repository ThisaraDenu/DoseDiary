import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/services/live_presence_service.dart';
import '../../data/local/models/app_models.dart';
import '../../data/remote/auth_service.dart';
import '../../data/remote/supabase_sync_service.dart';
import '../../data/repositories/app_repositories.dart';
import '../../data/repositories/notification_repository.dart';

/// Checks for invitations addressed to the current account and presents the
/// newest one as an in-app popup from any main app tab.
class ConnectionInvitationPrompt extends ConsumerStatefulWidget {
  const ConnectionInvitationPrompt({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ConnectionInvitationPrompt> createState() =>
      _ConnectionInvitationPromptState();
}

class _ConnectionInvitationPromptState
    extends ConsumerState<ConnectionInvitationPrompt>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  Timer? _presenceTimer;
  final Set<String> _handledInSession = {};
  bool _dialogOpen = false;
  bool _presenceSyncRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      unawaited(_syncPresenceAndConnections(forceLocation: true));
    });
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refresh(),
    );
    _presenceTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_syncPresenceAndConnections()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      unawaited(_syncPresenceAndConnections(forceLocation: true));
    }
  }

  void _refresh() {
    if (!mounted || !AuthService.isLoggedIn) return;
    ref.invalidate(directIncomingInvitationsProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _presenceTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncPresenceAndConnections({bool forceLocation = false}) async {
    if (!mounted || !AuthService.isLoggedIn || _presenceSyncRunning) return;
    _presenceSyncRunning = true;
    try {
      await LivePresenceService.publishNow(forceLocation: forceLocation);
      await SupabaseSyncService.pullConnectedPeople();
      if (!mounted) return;
      ref.invalidate(allocatedPatientsProvider);
      ref.invalidate(patientCaregiversListProvider);
      ref.invalidate(patientCaregiversProvider);
      ref.invalidate(caregiverPatientsProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
    } finally {
      _presenceSyncRunning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitations = ref.watch(directIncomingInvitationsProvider);
    invitations.whenData((items) {
      final pending =
          items.where((item) => !_handledInSession.contains(item.id)).toList();
      if (pending.isNotEmpty && !_dialogOpen) {
        _dialogOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showInvitation(pending.first);
        });
      }
    });
    return widget.child;
  }

  Future<void> _showInvitation(CaregiverInvitation invitation) async {
    final senderName = invitation.senderName?.trim().isNotEmpty == true
        ? invitation.senderName!.trim()
        : 'A DoseDiary user';
    final message = invitation.senderRole == 'caregiver'
        ? '$senderName wants to connect as your caregiver.'
        : '$senderName wants you to be their caregiver.';

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.people_alt_rounded,
          color: AppColors.primaryAction,
          size: 34,
        ),
        title: const Text('Connection invitation'),
        content: Text('$message\n\nRelationship: ${invitation.relationship}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Decline',
              style: TextStyle(color: AppColors.error),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    try {
      await ref
          .read(caregiverRepositoryProvider)
          .respondToDirectConnectionInvitation(
            invitationId: invitation.id,
            accept: accepted == true,
          );
      _handledInSession.add(invitation.id);
      ref.invalidate(directIncomingInvitationsProvider);
      ref.invalidate(incomingCaregiverInvitationsProvider);
      ref.invalidate(allocatedPatientsProvider);
      ref.invalidate(patientCaregiversListProvider);
      ref.invalidate(patientCaregiversProvider);
      ref.invalidate(caregiverPatientsProvider);
      ref.invalidate(caregiversProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accepted == true
                  ? 'Connected with $senderName.'
                  : 'Invitation declined.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not answer invitation: $error'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _dialogOpen = false;
      if (mounted) _refresh();
    }
  }
}
