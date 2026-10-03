import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../local/database_provider.dart';
import '../local/models/app_models.dart';

const _uuid = Uuid();

/// Repository handling all SQLite database CRUD operations for Patient & Caregiver management.
class CaregiverRepository {
  CaregiverRepository(this._db);
  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  // ── Patient-Side Operations ──────────────────────────────────────────────

  /// 1. createInvitation
  /// Creates a new CaregiverInvitation and linked default CaregiverPermission.
  /// Prevents duplicate active/pending invitations for the same patient and caregiver email.
  Future<CaregiverInvitation> createInvitation({
    required String userId,
    required String caregiverEmail,
    String relationship = 'Family member',
    CaregiverPermission? permissions,
    String? token,
    DateTime? expiresAt,
  }) async {
    final db = await _database;
    final cleanEmail = caregiverEmail.trim().toLowerCase();

    // Check for existing pending invitation for same patient + email
    final existingRows = await db.query(
      'caregiver_invitations',
      where: 'user_id = ? AND LOWER(caregiver_email) = ? AND status = ?',
      whereArgs: [userId, cleanEmail, 'pending'],
      limit: 1,
    );

    if (existingRows.isNotEmpty) {
      return CaregiverInvitation.fromMap(existingRows.first);
    }

    final now = DateTime.now().toUtc();
    final inviteToken = token ?? _uuid.v4();
    final invitation = CaregiverInvitation(
      id: _uuid.v4(),
      userId: userId,
      caregiverEmail: cleanEmail,
      relationship: relationship,
      status: 'pending',
      token: inviteToken,
      expiresAt: expiresAt ?? now.add(const Duration(days: 7)),
      createdAt: now,
      updatedAt: now,
    );

    final initialPerms = permissions ??
        CaregiverPermission.create(
          invitationId: invitation.id,
          userId: userId,
          permViewSchedule: true,
          permViewHistory: true,
          permViewRefills: false,
          permViewAdherence: true,
        );

    await db.transaction((txn) async {
      await txn.insert(
        'caregiver_invitations',
        invitation.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final permToInsert = initialPerms.copyWith(
        invitationId: invitation.id,
        userId: userId,
      );
      await txn.insert(
        'caregiver_permissions',
        permToInsert.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    return invitation;
  }

  /// 2. getCaregiverInvitationsForPatient
  /// Returns all invitations sent by the patient (newest first).
  Future<List<CaregiverInvitation>> getCaregiverInvitationsForPatient(
      String patientId) async {
    final db = await _database;
    final rows = await db.query(
      'caregiver_invitations',
      where: 'user_id = ?',
      whereArgs: [patientId],
      orderBy: 'created_at DESC',
    );
    return rows.map(CaregiverInvitation.fromMap).toList();
  }

  /// 3. getInvitationById
  /// Returns single invitation or null if not found.
  Future<CaregiverInvitation?> getInvitationById(String invitationId) async {
    final db = await _database;
    final rows = await db.query(
      'caregiver_invitations',
      where: 'id = ?',
      whereArgs: [invitationId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CaregiverInvitation.fromMap(rows.first);
  }

  /// 4. updateInvitation
  /// Updates allowed relationship / expiry fields while preserving IDs.
  Future<void> updateInvitation(CaregiverInvitation invitation) async {
    final db = await _database;
    final updated = invitation.copyWith(updatedAt: DateTime.now().toUtc());
    await db.update(
      'caregiver_invitations',
      updated.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [invitation.id, invitation.userId],
    );
  }

  /// 5. revokeCaregiver
  /// Soft revokes invitation status to 'revoked' and disables all permission toggles.
  Future<void> revokeCaregiver(String invitationId) async {
    final db = await _database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        'caregiver_invitations',
        {
          'status': 'revoked',
          'updated_at': nowIso,
        },
        where: 'id = ?',
        whereArgs: [invitationId],
      );

      await txn.update(
        'caregiver_permissions',
        {
          'perm_view_schedule': 0,
          'perm_view_history': 0,
          'perm_view_refills': 0,
          'perm_view_adherence': 0,
          'updated_at': nowIso,
        },
        where: 'invitation_id = ?',
        whereArgs: [invitationId],
      );
    });
  }

  /// 6. updateCaregiverPermissions
  /// Inserts or updates caregiver permissions record in SQLite.
  Future<void> updateCaregiverPermissions(CaregiverPermission permission) async {
    final db = await _database;
    final updated = permission.copyWith(updatedAt: DateTime.now().toUtc());
    await db.insert(
      'caregiver_permissions',
      updated.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 7. getPermissionsForRelationship
  /// Returns CaregiverPermission by invitationId or patientId & caregiverId.
  Future<CaregiverPermission?> getPermissionsForRelationship({
    String? invitationId,
    String? patientId,
    String? caregiverId,
  }) async {
    final db = await _database;
    List<Map<String, dynamic>> rows = [];

    if (invitationId != null && invitationId.isNotEmpty) {
      rows = await db.query(
        'caregiver_permissions',
        where: 'invitation_id = ?',
        whereArgs: [invitationId],
        limit: 1,
      );
    } else if (patientId != null && caregiverId != null) {
      rows = await db.query(
        'caregiver_permissions',
        where: 'user_id = ? AND caregiver_id = ?',
        whereArgs: [patientId, caregiverId],
        limit: 1,
      );
    }

    if (rows.isEmpty) return null;
    return CaregiverPermission.fromMap(rows.first);
  }

  // ── Caregiver-Side Operations ────────────────────────────────────────────

  /// 8. getPendingInvitationsForCaregiver
  /// Returns pending invitations matching caregiver's email (newest first).
  Future<List<CaregiverInvitation>> getPendingInvitationsForCaregiver(
      String caregiverEmail) async {
    final db = await _database;
    final cleanEmail = caregiverEmail.trim().toLowerCase();
    final rows = await db.query(
      'caregiver_invitations',
      where: 'LOWER(caregiver_email) = ? AND status = ?',
      whereArgs: [cleanEmail, 'pending'],
      orderBy: 'created_at DESC',
    );
    return rows.map(CaregiverInvitation.fromMap).toList();
  }

  /// 9. acceptInvitation
  /// Updates invitation status to 'accepted' and associates caregiverId with permissions.
  Future<void> acceptInvitation({
    required String invitationId,
    required String caregiverId,
  }) async {
    final db = await _database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        'caregiver_invitations',
        {
          'status': 'accepted',
          'updated_at': nowIso,
        },
        where: 'id = ?',
        whereArgs: [invitationId],
      );

      await txn.update(
        'caregiver_permissions',
        {
          'caregiver_id': caregiverId,
          'updated_at': nowIso,
        },
        where: 'invitation_id = ?',
        whereArgs: [invitationId],
      );
    });
  }

  /// 10. declineInvitation
  /// Updates invitation status to 'declined'.
  Future<void> declineInvitation(String invitationId) async {
    final db = await _database;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'caregiver_invitations',
      {
        'status': 'declined',
        'updated_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [invitationId],
    );
  }

  /// 11. getConnectedPatientsForCaregiver
  /// Joins caregiver_permissions, caregiver_invitations, and profiles to return connected patients.
  Future<List<ConnectedPatient>> getConnectedPatientsForCaregiver(
      String caregiverId) async {
    final db = await _database;
    const sql = '''
      SELECT 
        cp.user_id AS patient_id,
        COALESCE(p.full_name, 'Patient') AS full_name,
        p.avatar_url,
        ci.relationship,
        ci.status AS invitation_status,
        ci.created_at,
        cp.id AS perm_id,
        cp.invitation_id,
        cp.user_id,
        cp.caregiver_id,
        cp.perm_view_schedule,
        cp.perm_view_history,
        cp.perm_view_refills,
        cp.perm_view_adherence,
        cp.alert_important_only,
        cp.retry_count,
        cp.grace_period_minutes,
        cp.created_at AS perm_created_at,
        cp.updated_at AS perm_updated_at
      FROM caregiver_permissions cp
      JOIN caregiver_invitations ci ON cp.invitation_id = ci.id
      LEFT JOIN profiles p ON cp.user_id = p.id
      WHERE cp.caregiver_id = ? AND ci.status = 'accepted'
      ORDER BY ci.created_at DESC
    ''';

    final rows = await db.rawQuery(sql, [caregiverId]);
    return rows.map((row) {
      final permMap = {
        'id': row['perm_id'] ?? row['invitation_id'],
        'invitation_id': row['invitation_id'],
        'user_id': row['user_id'],
        'caregiver_id': row['caregiver_id'],
        'perm_view_schedule': row['perm_view_schedule'],
        'perm_view_history': row['perm_view_history'],
        'perm_view_refills': row['perm_view_refills'],
        'perm_view_adherence': row['perm_view_adherence'],
        'alert_important_only': row['alert_important_only'],
        'retry_count': row['retry_count'],
        'grace_period_minutes': row['grace_period_minutes'],
        'created_at': row['perm_created_at'] ?? row['created_at'],
        'updated_at': row['perm_updated_at'] ?? row['created_at'],
      };

      return ConnectedPatient(
        patientId: row['patient_id'] as String,
        fullName: row['full_name'] as String? ?? 'Patient',
        avatarUrl: row['avatar_url'] as String?,
        relationship: row['relationship'] as String? ?? 'Family member',
        permission: CaregiverPermission.fromMap(permMap),
        invitationStatus: row['invitation_status'] as String? ?? 'accepted',
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  /// 12. disconnectPatient
  /// Ends caregiver-patient relationship by setting invitation status to 'revoked'
  /// and disabling permissions. Does not delete profiles.
  Future<void> disconnectPatient({
    required String patientId,
    required String caregiverId,
  }) async {
    final db = await _database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.rawUpdate(
        '''
        UPDATE caregiver_invitations
        SET status = 'revoked', updated_at = ?
        WHERE user_id = ? AND id IN (
          SELECT invitation_id FROM caregiver_permissions WHERE caregiver_id = ?
        )
        ''',
        [nowIso, patientId, caregiverId],
      );

      await txn.update(
        'caregiver_permissions',
        {
          'perm_view_schedule': 0,
          'perm_view_history': 0,
          'perm_view_refills': 0,
          'perm_view_adherence': 0,
          'updated_at': nowIso,
        },
        where: 'user_id = ? AND caregiver_id = ?',
        whereArgs: [patientId, caregiverId],
      );
    });
  }
}

// ── Riverpod Provider ─────────────────────────────────────────────────────────

final caregiverRepositoryProvider = Provider<CaregiverRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CaregiverRepository(db);
});
