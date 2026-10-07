import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../local/database_provider.dart';
import '../local/models/app_models.dart';
import '../local/models/dose_status.dart';
import '../remote/auth_service.dart';
import '../remote/supabase_sync_service.dart';

/// Returns the currently authenticated user's ID, or falls back to 'guest-user'.
String get _activeUserId => AuthService.currentUser?.id ?? 'guest-user';

// ── Medication Repository ─────────────────────────────────────────────────────

class MedicationRepository {
  MedicationRepository(this._db);
  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  Future<List<Medication>> getMedications({bool activeOnly = true}) async {
    final db = await _database;
    final userId = _activeUserId;
    final where = activeOnly ? 'user_id = ? AND is_active = 1' : 'user_id = ?';
    final rows = await db.query('medications', where: where, whereArgs: [userId]);
    return rows.map(Medication.fromMap).toList();
  }

  Future<Medication?> getMedicationById(String id) async {
    final db = await _database;
    final rows = await db.query('medications', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Medication.fromMap(rows.first);
  }

  Future<void> insertMedication(Medication med) async {
    final db = await _database;
    await db.insert('medications', med.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    SupabaseSyncService.pushMedication(med.toMap()).ignore();
  }

  Future<void> updateMedication(Medication med) async {
    final db = await _database;
    await db.update('medications', med.toMap(), where: 'id = ?', whereArgs: [med.id]);
    SupabaseSyncService.pushMedication(med.toMap()).ignore();
  }

  Future<void> archiveMedication(String id) async {
    final db = await _database;
    final updatedAt = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'medications',
      {'is_active': 0, 'updated_at': updatedAt},
      where: 'id = ?',
      whereArgs: [id],
    );
    final med = await getMedicationById(id);
    if (med != null) {
      SupabaseSyncService.pushMedication(med.toMap()).ignore();
    }
  }

  Future<void> updateQuantity(String medicationId, double newQty) async {
    final db = await _database;
    final updatedAt = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'medications',
      {'quantity_on_hand': newQty, 'updated_at': updatedAt},
      where: 'id = ?',
      whereArgs: [medicationId],
    );
    final med = await getMedicationById(medicationId);
    if (med != null) {
      SupabaseSyncService.pushMedication(med.toMap()).ignore();
    }
  }
}

// ── Dose Repository ───────────────────────────────────────────────────────────

class DoseRepository {
  DoseRepository(this._db);
  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  Future<List<DoseOccurrence>> getOccurrencesForDate(DateTime date) async {
    final db = await _database;
    final userId = _activeUserId;
    final localDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    await _ensureOccurrencesForDate(db, userId, date, localDate);

    final rows = await db.query(
      'dose_occurrences',
      where: 'user_id = ? AND local_date = ?',
      whereArgs: [userId, localDate],
      orderBy: 'scheduled_at ASC',
    );
    return rows.map(DoseOccurrence.fromMap).toList();
  }

  Future<void> _ensureOccurrencesForDate(
    Database db,
    String userId,
    DateTime date,
    String localDate,
  ) async {
    try {
      final schedules = await db.query(
        'schedules',
        where: 'user_id = ? AND superseded_at IS NULL',
        whereArgs: [userId],
      );
      if (schedules.isEmpty) return;

      final startOfDay = DateTime(date.year, date.month, date.day);
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      for (final s in schedules) {
        final schedId = s['id'] as String;
        final medId = s['medication_id'] as String;
        final timesStr = s['times_of_day'] as String? ?? '';
        final times = timesStr.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

        final startDateStr = s['start_date'] as String?;
        if (startDateStr != null) {
          final sDate = DateTime.tryParse(startDateStr);
          if (sDate != null && startOfDay.isBefore(DateTime(sDate.year, sDate.month, sDate.day))) {
            continue;
          }
        }
        final endDateStr = s['end_date'] as String?;
        if (endDateStr != null) {
          final eDate = DateTime.tryParse(endDateStr);
          if (eDate != null && startOfDay.isAfter(DateTime(eDate.year, eDate.month, eDate.day))) {
            continue;
          }
        }

        final repeatDaysStr = s['repeat_days'] as String?;
        if (repeatDaysStr != null && repeatDaysStr.isNotEmpty) {
          final days = repeatDaysStr.split(',').map((d) => int.tryParse(d.trim())).whereType<int>().toList();
          if (days.isNotEmpty && !days.contains(date.weekday)) {
            continue;
          }
        }

        for (final time in times) {
          final key = '$schedId-$localDate-$time';
          final parts = time.split(':');
          if (parts.length < 2) continue;
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final scheduledAt = DateTime(date.year, date.month, date.day, h, m).toUtc();

          await db.insert(
            'dose_occurrences',
            {
              'id': '${schedId}_${localDate}_$time',
              'schedule_id': schedId,
              'medication_id': medId,
              'user_id': userId,
              'scheduled_at': scheduledAt.toIso8601String(),
              'local_date': localDate,
              'occurrence_key': key,
              'status': 'pending',
              'created_at': nowUtc,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    } catch (_) {}
  }

  Future<List<DoseOccurrence>> getOccurrencesForDateRange(
      DateTime start, DateTime end) async {
    final db = await _database;
    final userId = _activeUserId;
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();
    final rows = await db.query(
      'dose_occurrences',
      where: 'user_id = ? AND scheduled_at >= ? AND scheduled_at <= ?',
      whereArgs: [userId, startStr, endStr],
      orderBy: 'scheduled_at ASC',
    );
    return rows.map(DoseOccurrence.fromMap).toList();
  }

  Future<DoseOccurrence?> getOccurrenceById(String id) async {
    final db = await _database;
    final rows = await db.query('dose_occurrences', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return DoseOccurrence.fromMap(rows.first);
  }

  Future<void> insertOccurrence(DoseOccurrence occ) async {
    final db = await _database;
    await db.insert('dose_occurrences', occ.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    SupabaseSyncService.pushDoseOccurrence(occ.toMap()).ignore();
  }

  Future<void> updateOccurrenceStatus(
    String id,
    DoseStatus status, {
    DateTime? snoozeUntil,
  }) async {
    final db = await _database;
    final updates = <String, dynamic>{
      'status': status.toDbString(),
    };
    if (snoozeUntil != null) updates['snooze_until'] = snoozeUntil.toIso8601String();
    await db.update('dose_occurrences', updates, where: 'id = ?', whereArgs: [id]);
    final occ = await getOccurrenceById(id);
    if (occ != null) {
      SupabaseSyncService.pushDoseOccurrence(occ.toMap()).ignore();
    }
  }

  Future<void> insertDoseEvent(DoseEvent event) async {
    final db = await _database;
    await db.insert('dose_events', event.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    SupabaseSyncService.pushDoseEvent(event.toMap()).ignore();
  }

  Future<List<DoseEvent>> getEventsForOccurrence(String occurrenceId) async {
    final db = await _database;
    final rows = await db.query(
      'dose_events',
      where: 'occurrence_id = ?',
      whereArgs: [occurrenceId],
      orderBy: 'created_at DESC',
    );
    return rows.map(DoseEvent.fromMap).toList();
  }

  /// Adherence summary for a given day.
  /// Only counts past/current doses (not future doses).
  Future<AdherenceSummary> getDayAdherence(DateTime date) async {
    final occs = await getOccurrencesForDate(date);
    final now = DateTime.now();
    // Only count doses that are due or past
    final countable = occs.where((o) => o.scheduledAt.isBefore(now) || o.status.isTerminal).toList();
    final taken = countable.where((o) => o.status == DoseStatus.taken).length;
    final total = countable.length;
    return AdherenceSummary(taken: taken, total: total, countable: countable.length);
  }

  /// 7-day adherence report for caregiver and patient analytics.
  Future<WeeklyAdherenceReport> getWeeklyAdherenceReport({String? userId}) async {
    final now = DateTime.now();
    final pips = <DailyAdherencePip>[];
    int totalCountable = 0;
    int totalTaken = 0;

    // Loop from 6 days ago up to today (day 0)
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final summary = await getDayAdherence(day);
      totalCountable += summary.countable;
      totalTaken += summary.taken;

      final isToday = (i == 0);
      final dayLabel = isToday ? 'Today' : DateFormat('E').format(day);
      pips.add(DailyAdherencePip(
        dayLabel: dayLabel,
        percentage: summary.percentage,
        hasDoses: summary.countable > 0,
      ));
    }

    final overall = totalCountable == 0 ? 100.0 : (totalTaken / totalCountable * 100).clamp(0.0, 100.0);
    final missed = (totalCountable - totalTaken).clamp(0, 9999);

    return WeeklyAdherenceReport(
      overallPercentage: overall,
      totalCountable: totalCountable,
      totalTaken: totalTaken,
      totalMissed: missed,
      dailyPips: pips,
    );
  }

  /// Records a dose administered in person by caregiver into SQLite.
  Future<void> recordInPersonDose({
    required String medicationId,
    required String userId,
    double amount = 1.0,
    String? note,
  }) async {
    final db = await _database;
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final rows = await db.query(
      'dose_occurrences',
      where: 'medication_id = ? AND local_date = ? AND status != ?',
      whereArgs: [medicationId, todayStr, 'taken'],
      orderBy: 'scheduled_at ASC',
      limit: 1,
    );

    String occurrenceId;
    if (rows.isNotEmpty) {
      occurrenceId = rows.first['id'] as String;
      await updateOccurrenceStatus(occurrenceId, DoseStatus.taken);
    } else {
      occurrenceId = 'adhoc_${medicationId}_${DateTime.now().millisecondsSinceEpoch}';
      await db.insert('dose_occurrences', {
        'id': occurrenceId,
        'schedule_id': 'manual-caregiver',
        'medication_id': medicationId,
        'user_id': userId,
        'scheduled_at': now.toUtc().toIso8601String(),
        'local_date': todayStr,
        'occurrence_key': occurrenceId,
        'status': 'taken',
        'created_at': now.toUtc().toIso8601String(),
      });
    }

    final event = DoseEvent.create(
      occurrenceId: occurrenceId,
      userId: userId,
      action: 'taken',
      skipReason: note ?? 'Administered in-person by caregiver',
    );
    await insertDoseEvent(event);
  }
}


class AdherenceSummary {
  const AdherenceSummary({required this.taken, required this.total, required this.countable});
  final int taken;
  final int total;
  final int countable;
  double get percentage => countable == 0 ? 0 : (taken / countable * 100).clamp(0, 100);
  String get percentageStr => '${percentage.toStringAsFixed(0)}%';
}

class DailyAdherencePip {
  const DailyAdherencePip({
    required this.dayLabel,
    required this.percentage,
    required this.hasDoses,
  });

  final String dayLabel;
  final double percentage;
  final bool hasDoses;

  String get labelText {
    if (!hasDoses) return '$dayLabel • -';
    return '$dayLabel • ${percentage.toStringAsFixed(0)}%';
  }
}

class WeeklyAdherenceReport {
  const WeeklyAdherenceReport({
    required this.overallPercentage,
    required this.totalCountable,
    required this.totalTaken,
    required this.totalMissed,
    required this.dailyPips,
  });

  final double overallPercentage;
  final int totalCountable;
  final int totalTaken;
  final int totalMissed;
  final List<DailyAdherencePip> dailyPips;

  String get percentageStr => '${overallPercentage.toStringAsFixed(0)}%';
}

// ── Stock / Refill Repository ─────────────────────────────────────────────────

class RefillRepository {
  RefillRepository(this._db, this._medRepo);
  final AppDatabase _db;
  final MedicationRepository _medRepo;

  Future<Database> get _database => _db.database;

  Future<List<Medication>> getLowStockMedications() async {
    final meds = await _medRepo.getMedications();
    return meds.where((m) => m.isLowStock).toList();
  }

  Future<Medication?> getLowestStockMedication() async {
    final meds = await _medRepo.getMedications(activeOnly: true);
    if (meds.isEmpty) return null;
    final tracked = meds.where((m) => m.refillReminderEnabled).toList();
    final list = tracked.isNotEmpty ? List<Medication>.from(tracked) : List<Medication>.from(meds);
    list.sort((a, b) => a.quantityOnHand.compareTo(b.quantityOnHand));
    return list.first;
  }

  Future<void> recordRefill({
    required String medicationId,
    required String userId,
    required double quantityAdded,
    String? note,
  }) async {
    final med = await _medRepo.getMedicationById(medicationId);
    if (med == null) return;

    final newQty = med.quantityOnHand + quantityAdded;
    final event = StockEvent.create(
      medicationId: medicationId,
      userId: userId,
      eventType: 'refill',
      quantityDelta: quantityAdded,
      quantityAfter: newQty,
      note: note,
    );

    final db = await _database;
    await db.insert('stock_events', event.toMap());
    await _medRepo.updateQuantity(medicationId, newQty);
    SupabaseSyncService.pushStockEvent(event.toMap()).ignore();
  }

  Future<void> recordDeduction({
    required String medicationId,
    required String userId,
    required double amount,
    String? doseEventId,
  }) async {
    final med = await _medRepo.getMedicationById(medicationId);
    if (med == null) return;

    final newQty = (med.quantityOnHand - amount).clamp(0, double.infinity).toDouble();
    final event = StockEvent.create(
      medicationId: medicationId,
      userId: userId,
      eventType: 'deduction',
      quantityDelta: -amount,
      quantityAfter: newQty,
      doseEventId: doseEventId,
    );

    final db = await _database;
    await db.insert('stock_events', event.toMap());
    await _medRepo.updateQuantity(medicationId, newQty);
    SupabaseSyncService.pushStockEvent(event.toMap()).ignore();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final medicationRepositoryProvider = Provider<MedicationRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return MedicationRepository(db);
});

final doseRepositoryProvider = Provider<DoseRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DoseRepository(db);
});

final refillRepositoryProvider = Provider<RefillRepository>((ref) {
  final medRepo = ref.watch(medicationRepositoryProvider);
  final db = ref.watch(appDatabaseProvider);
  return RefillRepository(db, medRepo);
});

final allActiveMedsProvider = FutureProvider<List<Medication>>((ref) async {
  final repo = ref.watch(medicationRepositoryProvider);
  return repo.getMedications(activeOnly: true);
});

final medicationByIdProvider = FutureProvider.family<Medication?, String>((ref, id) async {
  final repo = ref.watch(medicationRepositoryProvider);
  return repo.getMedicationById(id);
});

final todayOccurrencesProvider = FutureProvider<List<DoseOccurrence>>((ref) async {
  final repo = ref.watch(doseRepositoryProvider);
  return repo.getOccurrencesForDate(DateTime.now());
});

final todayMedicationsProvider = FutureProvider<List<Medication>>((ref) async {
  final repo = ref.watch(medicationRepositoryProvider);
  return repo.getMedications();
});

final todayAdherenceProvider = FutureProvider<AdherenceSummary>((ref) async {
  final repo = ref.watch(doseRepositoryProvider);
  return repo.getDayAdherence(DateTime.now());
});

final lowStockProvider = FutureProvider<List<Medication>>((ref) async {
  final repo = ref.watch(refillRepositoryProvider);
  return repo.getLowStockMedications();
});

final weeklyAdherenceProvider = FutureProvider<WeeklyAdherenceReport>((ref) async {
  final repo = ref.watch(doseRepositoryProvider);
  return repo.getWeeklyAdherenceReport();
});

final lowestStockMedicationProvider = FutureProvider<Medication?>((ref) async {
  final repo = ref.watch(refillRepositoryProvider);
  return repo.getLowestStockMedication();
});

// ── Patient / Allocation Repository ──────────────────────────────────────────

class PatientRepository {
  PatientRepository(this._db);
  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  Future<List<AllocatedPatient>> getAllocatedPatients({String? caregiverId}) async {
    final cid = caregiverId ?? _activeUserId;
    final db = await _database;
    final rows = await db.query(
      'allocated_patients',
      where: 'caregiver_id = ?',
      whereArgs: [cid],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => AllocatedPatient.fromMap(r)).toList();
  }

  Future<void> addAllocatedPatient(AllocatedPatient patient) async {
    final db = await _database;
    await db.insert('allocated_patients', patient.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeAllocatedPatient(String patientId) async {
    final db = await _database;
    await db.delete('allocated_patients', where: 'id = ?', whereArgs: [patientId]);
  }
}

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PatientRepository(db);
});

final allocatedPatientsProvider = FutureProvider<List<AllocatedPatient>>((ref) async {
  final repo = ref.watch(patientRepositoryProvider);
  return repo.getAllocatedPatients();
});

// -- PatientCaregiverLink Repository (many-to-many) --

class PatientCaregiverLinkRepository {
  PatientCaregiverLinkRepository(this._db);
  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  // ---- Caregiver side: get all patients this caregiver monitors ----
  Future<List<PatientCaregiverLink>> getPatientsForCaregiver({String? caregiverUserId}) async {
    final cid = caregiverUserId ?? _activeUserId;
    final db = await _database;
    final rows = await db.query(
      'patient_caregiver_links',
      where: 'caregiver_user_id = ? AND status = ?',
      whereArgs: [cid, 'active'],
      orderBy: 'created_at ASC',
    );
    return rows.map(PatientCaregiverLink.fromMap).toList();
  }

  // ---- Patient side: get all caregivers watching this patient ----
  Future<List<PatientCaregiverLink>> getCaregiversForPatient({String? patientUserId}) async {
    final pid = patientUserId ?? _activeUserId;
    final db = await _database;
    final rows = await db.query(
      'patient_caregiver_links',
      where: 'patient_user_id = ? AND status = ?',
      whereArgs: [pid, 'active'],
      orderBy: 'created_at ASC',
    );
    return rows.map(PatientCaregiverLink.fromMap).toList();
  }

  // ---- Create a new link (e.g., after invitation accepted) ----
  Future<PatientCaregiverLink> createLink({
    required String patientUserId,
    required String caregiverUserId,
    String relationship = 'Caregiver',
    String? invitationId,
  }) async {
    final link = PatientCaregiverLink.create(
      patientUserId: patientUserId,
      caregiverUserId: caregiverUserId,
      relationship: relationship,
      invitationId: invitationId,
    );
    final db = await _database;
    await db.insert(
      'patient_caregiver_links',
      link.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return link;
  }

  // ---- Update status (pause / revoke) ----
  Future<void> updateLinkStatus(String linkId, String status) async {
    final db = await _database;
    await db.update(
      'patient_caregiver_links',
      {'status': status, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [linkId],
    );
  }

  // ---- Remove a link entirely ----
  Future<void> deleteLink(String linkId) async {
    final db = await _database;
    await db.delete('patient_caregiver_links', where: 'id = ?', whereArgs: [linkId]);
  }

  // ---- Check if a specific link exists ----
  Future<bool> linkExists({
    required String patientUserId,
    required String caregiverUserId,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'patient_caregiver_links',
      where: 'patient_user_id = ? AND caregiver_user_id = ?',
      whereArgs: [patientUserId, caregiverUserId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}

final patientCaregiverLinkRepositoryProvider = Provider<PatientCaregiverLinkRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PatientCaregiverLinkRepository(db);
});

/// All active patients that the current caregiver is monitoring.
final caregiverPatientsProvider = FutureProvider<List<PatientCaregiverLink>>((ref) async {
  final repo = ref.watch(patientCaregiverLinkRepositoryProvider);
  return repo.getPatientsForCaregiver();
});

/// All active caregivers assigned to the current patient.
final patientCaregiversProvider = FutureProvider<List<PatientCaregiverLink>>((ref) async {
  final repo = ref.watch(patientCaregiverLinkRepositoryProvider);
  return repo.getCaregiversForPatient();
});

// ── Caregiver Repository (Patient Mode) ───────────────────────────────────────
// Manages the caregivers that a patient sees in Patient Mode.
// Backed by SQLite table 'allocated_caregivers'.

class CaregiverRepository {
  CaregiverRepository(this._db);
  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  /// Returns all caregivers assigned to this patient.
  Future<List<AllocatedCaregiver>> getCaregiversForPatient({String? patientId}) async {
    final pid = patientId ?? _activeUserId;
    final db = await _database;
    final rows = await db.query(
      'allocated_caregivers',
      where: 'patient_id = ?',
      whereArgs: [pid],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => AllocatedCaregiver.fromMap(r)).toList();
  }

  /// Adds a caregiver for this patient into local SQLite.
  Future<void> addCaregiver(AllocatedCaregiver caregiver) async {
    final db = await _database;
    await db.insert(
      'allocated_caregivers',
      caregiver.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Removes a caregiver by their ID.
  Future<void> removeCaregiver(String caregiverId) async {
    final db = await _database;
    await db.delete(
      'allocated_caregivers',
      where: 'id = ?',
      whereArgs: [caregiverId],
    );
  }

  // ── Caregiver Invitations (Patient ↔ Caregiver Onboarding) ───────────────────

  /// Returns all caregiver invitations created by this patient from SQLite.
  Future<List<CaregiverInvitation>> getInvitations({String? userId}) async {
    final uid = userId ?? _activeUserId;
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT i.*,
             p.perm_view_schedule,
             p.perm_view_history,
             p.perm_view_refills,
             p.perm_view_adherence
      FROM caregiver_invitations i
      LEFT JOIN caregiver_permissions p ON p.invitation_id = i.id
      WHERE i.user_id = ?
      ORDER BY i.created_at DESC
    ''', [uid]);

    return rows.map((r) => CaregiverInvitation.fromMap(r)).toList();
  }

  /// Validates the invitation inputs against all business rules.
  /// Returns null if valid, or a descriptive error message if invalid.
  Future<String?> validateInvitation({
    required String caregiverEmail,
    String? patientUserId,
    String? patientUserEmail,
  }) async {
    final email = caregiverEmail.trim().toLowerCase();

    if (email.isEmpty) {
      return 'Please enter a caregiver email address.';
    }

    final emailRegex = RegExp(r'^[\w\.\+\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }

    // Rule: Prevent linking the patient to themselves
    final currentEmail = (patientUserEmail ?? AuthService.currentUser?.email)?.trim().toLowerCase();
    if (currentEmail != null && currentEmail.isNotEmpty && currentEmail == email) {
      return 'You cannot invite yourself as a caregiver.';
    }

    final uid = patientUserId ?? _activeUserId;
    final db = await _database;

    // Rule: Prevent duplicate pending caregiver invitations
    final pendingRows = await db.query(
      'caregiver_invitations',
      where: 'user_id = ? AND LOWER(caregiver_email) = ? AND status = ?',
      whereArgs: [uid, email, 'pending'],
      limit: 1,
    );
    if (pendingRows.isNotEmpty) {
      return 'An invitation to this caregiver is already pending.';
    }

    // Rule: Prevent adding the same caregiver twice (already active or accepted)
    final activeRows = await db.query(
      'caregiver_invitations',
      where: 'user_id = ? AND LOWER(caregiver_email) = ? AND (status = ? OR status = ?)',
      whereArgs: [uid, email, 'accepted', 'active'],
      limit: 1,
    );
    if (activeRows.isNotEmpty) {
      return 'This caregiver is already connected to your account.';
    }

    return null;
  }

  /// Creates an invitation record and associated permissions in local SQLite,
  /// then pushes to Supabase asynchronously. Caregiver access is not granted
  /// immediately (status remains 'pending').
  Future<CaregiverInvitation> createInvitation({
    required String caregiverEmail,
    String relationship = 'Family member',
    bool viewSchedule = true,
    bool viewHistory = true,
    bool viewRefills = false,
    bool viewAdherence = true,
    String? patientUserId,
    String? patientUserEmail,
  }) async {
    final validationError = await validateInvitation(
      caregiverEmail: caregiverEmail,
      patientUserId: patientUserId,
      patientUserEmail: patientUserEmail,
    );
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final uid = patientUserId ?? _activeUserId;
    final db = await _database;
    final normalizedEmail = caregiverEmail.trim().toLowerCase();

    final invitation = CaregiverInvitation.create(
      userId: uid,
      email: normalizedEmail,
      relationship: relationship.trim().isEmpty ? 'Family member' : relationship.trim(),
      status: 'pending',
      viewSchedule: viewSchedule,
      viewHistory: viewHistory,
      viewRefills: viewRefills,
      viewAdherence: viewAdherence,
    );

    final permission = CaregiverPermission.create(
      invitationId: invitation.id,
      userId: uid,
      permViewSchedule: viewSchedule,
      permViewHistory: viewHistory,
      permViewRefills: viewRefills,
      permViewAdherence: viewAdherence,
    );

    await db.transaction((txn) async {
      await txn.insert(
        'caregiver_invitations',
        invitation.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'caregiver_permissions',
        permission.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    // Sync to Supabase cloud asynchronously
    SupabaseSyncService.pushCaregiverInvitation(invitation.toMap()).ignore();
    SupabaseSyncService.pushCaregiverPermission(permission.toMap()).ignore();

    return invitation;
  }

  /// Revokes an invitation by ID, updating status to 'revoked' and syncing to Supabase.
  Future<void> revokeInvitation(String invitationId) async {
    final db = await _database;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'caregiver_invitations',
      {'status': 'revoked', 'updated_at': nowIso},
      where: 'id = ?',
      whereArgs: [invitationId],
    );

    final rows = await db.query(
      'caregiver_invitations',
      where: 'id = ?',
      whereArgs: [invitationId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      SupabaseSyncService.pushCaregiverInvitation(rows.first).ignore();
    }
  }

  /// Permanently removes an invitation record and its permissions by ID from SQLite.
  Future<void> deleteInvitation(String invitationId) async {
    final db = await _database;
    await db.delete('caregiver_permissions', where: 'invitation_id = ?', whereArgs: [invitationId]);
    await db.delete('caregiver_invitations', where: 'id = ?', whereArgs: [invitationId]);
  }

  // ── Caregiver-Side Incoming Invitations ────────────────────────────────────

  /// Returns all incoming invitations addressed to this caregiver (filtered by caregiver email).
  ///
  /// CRITICAL SECURITY / ISOLATION:
  /// - Does NOT use patient user_id.
  /// - Strictly matches LOWER(caregiver_email) against the authenticated caregiver's email.
  /// - Returns invitations joined with caregiver_permissions and patient profile full name.
  Future<List<CaregiverInvitation>> getIncomingInvitations({String? caregiverEmail}) async {
    final email = (caregiverEmail ?? AuthService.currentUser?.email)?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      return [];
    }

    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT i.*,
             p.perm_view_schedule,
             p.perm_view_history,
             p.perm_view_refills,
             p.perm_view_adherence,
             prof.full_name AS patient_name
      FROM caregiver_invitations i
      LEFT JOIN caregiver_permissions p ON p.invitation_id = i.id
      LEFT JOIN profiles prof ON prof.id = i.user_id
      WHERE LOWER(i.caregiver_email) = ?
      ORDER BY i.created_at DESC
    ''', [email]);

    return rows.map((r) => CaregiverInvitation.fromMap(r)).toList();
  }

  /// Updates status of an incoming invitation ('accepted' or 'declined') in SQLite
  /// and syncs to Supabase. Does not prematurely create patient-caregiver links.
  Future<void> respondToIncomingInvitation({
    required String invitationId,
    required String status,
  }) async {
    final normalizedStatus = status.trim().toLowerCase();
    if (normalizedStatus != 'accepted' && normalizedStatus != 'declined') {
      throw ArgumentError("Status must be either 'accepted' or 'declined'.");
    }

    final db = await _database;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'caregiver_invitations',
      {'status': normalizedStatus, 'updated_at': nowIso},
      where: 'id = ?',
      whereArgs: [invitationId],
    );

    final rows = await db.query(
      'caregiver_invitations',
      where: 'id = ?',
      whereArgs: [invitationId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      SupabaseSyncService.pushCaregiverInvitation(rows.first).ignore();
    }
  }

  /// Convenience helper to accept an incoming invitation.
  Future<void> acceptIncomingInvitation(String invitationId) =>
      respondToIncomingInvitation(invitationId: invitationId, status: 'accepted');

  /// Convenience helper to decline an incoming invitation.
  Future<void> declineIncomingInvitation(String invitationId) =>
      respondToIncomingInvitation(invitationId: invitationId, status: 'declined');
}

final caregiverRepositoryProvider = Provider<CaregiverRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CaregiverRepository(db);
});

/// Patient Mode: all caregivers linked to the current patient.
final patientCaregiversListProvider = FutureProvider<List<AllocatedCaregiver>>((ref) async {
  final repo = ref.watch(caregiverRepositoryProvider);
  return repo.getCaregiversForPatient();
});

/// Patient Mode: all caregiver invitations created by the current patient.
final caregiversProvider = FutureProvider<List<CaregiverInvitation>>((ref) async {
  final repo = ref.watch(caregiverRepositoryProvider);
  return repo.getInvitations();
});

/// Caregiver Mode: all incoming invitations addressed to the current caregiver.
final incomingCaregiverInvitationsProvider = FutureProvider<List<CaregiverInvitation>>((ref) async {
  final repo = ref.watch(caregiverRepositoryProvider);
  return repo.getIncomingInvitations();
});

