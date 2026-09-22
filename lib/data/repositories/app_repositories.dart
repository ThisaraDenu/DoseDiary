import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final rows = await db.query(
      'dose_occurrences',
      where: 'user_id = ? AND local_date = ?',
      whereArgs: [userId, localDate],
      orderBy: 'scheduled_at ASC',
    );
    return rows.map(DoseOccurrence.fromMap).toList();
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
}

class AdherenceSummary {
  const AdherenceSummary({required this.taken, required this.total, required this.countable});
  final int taken;
  final int total;
  final int countable;
  double get percentage => countable == 0 ? 0 : (taken / countable * 100).clamp(0, 100);
  String get percentageStr => '${percentage.toStringAsFixed(0)}%';
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
