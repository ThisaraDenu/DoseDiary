import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/models/app_models.dart';
import '../../data/remote/auth_service.dart';
import '../../data/repositories/caregiver_repository.dart';

// ── 1. Authentication / Identity Providers ─────────────────────────────────────

final activeUserIdProvider = Provider<String>((ref) {
  return AuthService.currentUser?.id ?? 'guest-user';
});

final activeUserEmailProvider = Provider<String>((ref) {
  return AuthService.currentUser?.email ?? 'guest@example.com';
});

// ── 2. Patient Caregiver Invitations Provider ─────────────────────────────────

class CaregiverInvitationsNotifier extends AsyncNotifier<List<CaregiverInvitation>> {
  @override
  Future<List<CaregiverInvitation>> build() async {
    final userId = ref.watch(activeUserIdProvider);
    final repo = ref.watch(caregiverRepositoryProvider);
    return repo.getCaregiverInvitationsForPatient(userId);
  }

  Future<void> loadInvitations([String? patientId]) async {
    final pid = patientId ?? ref.read(activeUserIdProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(caregiverRepositoryProvider);
      return repo.getCaregiverInvitationsForPatient(pid);
    });
  }

  Future<void> refresh([String? patientId]) async {
    await loadInvitations(patientId);
  }

  Future<CaregiverInvitation> createInvitation({
    required String caregiverEmail,
    String relationship = 'Family member',
    CaregiverPermission? permissions,
    String? token,
    DateTime? expiresAt,
    String? patientId,
  }) async {
    final pid = patientId ?? ref.read(activeUserIdProvider);
    final repo = ref.read(caregiverRepositoryProvider);
    final invitation = await repo.createInvitation(
      userId: pid,
      caregiverEmail: caregiverEmail,
      relationship: relationship,
      permissions: permissions,
      token: token,
      expiresAt: expiresAt,
    );
    await refresh(pid);
    return invitation;
  }

  Future<void> updateInvitation(CaregiverInvitation invitation) async {
    final repo = ref.read(caregiverRepositoryProvider);
    await repo.updateInvitation(invitation);
    await refresh(invitation.userId);
  }

  Future<void> revokeCaregiver(String invitationId, [String? patientId]) async {
    final repo = ref.read(caregiverRepositoryProvider);
    await repo.revokeCaregiver(invitationId);
    final pid = patientId ?? ref.read(activeUserIdProvider);
    await refresh(pid);
  }

  Future<void> updatePermissions(CaregiverPermission permission) async {
    final repo = ref.read(caregiverRepositoryProvider);
    await repo.updateCaregiverPermissions(permission);
    await refresh(permission.userId);
  }
}

final caregiverInvitationsProvider =
    AsyncNotifierProvider<CaregiverInvitationsNotifier, List<CaregiverInvitation>>(
  CaregiverInvitationsNotifier.new,
);

/// Backward-compatible provider for existing UI screens
final caregiversProvider = Provider<List<CaregiverInvitation>>((ref) {
  final asyncState = ref.watch(caregiverInvitationsProvider);
  return asyncState.valueOrNull ?? [];
});

// ── 3. Caregiver Permission Provider ──────────────────────────────────────────

class CaregiverPermissionNotifier
    extends FamilyAsyncNotifier<CaregiverPermission?, String> {
  @override
  Future<CaregiverPermission?> build(String arg) async {
    final repo = ref.watch(caregiverRepositoryProvider);
    return repo.getPermissionsForRelationship(invitationId: arg);
  }

  Future<void> loadPermissions(String invitationId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(caregiverRepositoryProvider);
      return repo.getPermissionsForRelationship(invitationId: invitationId);
    });
  }

  Future<void> updatePermissions(CaregiverPermission permission) async {
    final repo = ref.read(caregiverRepositoryProvider);
    await repo.updateCaregiverPermissions(permission);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return repo.getPermissionsForRelationship(invitationId: permission.invitationId);
    });
    ref.read(caregiverInvitationsProvider.notifier).refresh(permission.userId);
  }
}

final caregiverPermissionsProvider = AsyncNotifierProviderFamily<
    CaregiverPermissionNotifier, CaregiverPermission?, String>(
  CaregiverPermissionNotifier.new,
);

// ── 4. Caregiver-Side Pending Invitations Provider ────────────────────────────

class PendingInvitationsNotifier extends AsyncNotifier<List<CaregiverInvitation>> {
  @override
  Future<List<CaregiverInvitation>> build() async {
    final email = ref.watch(activeUserEmailProvider);
    final repo = ref.watch(caregiverRepositoryProvider);
    return repo.getPendingInvitationsForCaregiver(email);
  }

  Future<void> loadPendingInvitations([String? email]) async {
    final mail = email ?? ref.read(activeUserEmailProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(caregiverRepositoryProvider);
      return repo.getPendingInvitationsForCaregiver(mail);
    });
  }

  Future<void> refresh([String? email]) async {
    await loadPendingInvitations(email);
  }

  Future<void> acceptInvitation({
    required String invitationId,
    String? caregiverId,
  }) async {
    final cid = caregiverId ?? ref.read(activeUserIdProvider);
    final repo = ref.read(caregiverRepositoryProvider);
    await repo.acceptInvitation(invitationId: invitationId, caregiverId: cid);
    await refresh();
    ref.read(connectedPatientsProvider.notifier).refresh(cid);
  }

  Future<void> declineInvitation(String invitationId) async {
    final repo = ref.read(caregiverRepositoryProvider);
    await repo.declineInvitation(invitationId);
    await refresh();
  }
}

final pendingInvitationsProvider =
    AsyncNotifierProvider<PendingInvitationsNotifier, List<CaregiverInvitation>>(
  PendingInvitationsNotifier.new,
);

// ── 5. Connected Patients Provider ─────────────────────────────────────────────

class ConnectedPatientsNotifier extends AsyncNotifier<List<ConnectedPatient>> {
  @override
  Future<List<ConnectedPatient>> build() async {
    final caregiverId = ref.watch(activeUserIdProvider);
    final repo = ref.watch(caregiverRepositoryProvider);
    return repo.getConnectedPatientsForCaregiver(caregiverId);
  }

  Future<void> loadPatients([String? caregiverId]) async {
    final cid = caregiverId ?? ref.read(activeUserIdProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(caregiverRepositoryProvider);
      return repo.getConnectedPatientsForCaregiver(cid);
    });
  }

  Future<void> refresh([String? caregiverId]) async {
    await loadPatients(caregiverId);
  }

  Future<void> disconnectPatient({
    required String patientId,
    String? caregiverId,
  }) async {
    final cid = caregiverId ?? ref.read(activeUserIdProvider);
    final repo = ref.read(caregiverRepositoryProvider);
    await repo.disconnectPatient(patientId: patientId, caregiverId: cid);
    await refresh(cid);
  }
}

final connectedPatientsProvider =
    AsyncNotifierProvider<ConnectedPatientsNotifier, List<ConnectedPatient>>(
  ConnectedPatientsNotifier.new,
);

// ── 6. Lightweight UI Selection Providers ─────────────────────────────────────

final selectedCaregiverInvitationProvider =
    StateProvider<CaregiverInvitation?>((ref) => null);

final selectedConnectedPatientProvider =
    StateProvider<ConnectedPatient?>((ref) => null);
