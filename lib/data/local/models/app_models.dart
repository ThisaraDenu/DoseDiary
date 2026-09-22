import 'package:uuid/uuid.dart';
import 'dose_status.dart';

const _uuid = Uuid();

// ── Medication ────────────────────────────────────────────────────────────────

class Medication {
  const Medication({
    required this.id,
    required this.userId,
    required this.name,
    required this.strength,
    required this.strengthUnit,
    required this.amountPerDose,
    required this.doseUnit,
    this.instructions,
    required this.isActive,
    this.isAsNeeded = false,
    required this.quantityOnHand,
    required this.quantityUnit,
    this.refillReminderEnabled = false,
    this.refillThresholdQty,
    this.refillReminderDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final double strength;
  final String strengthUnit; // e.g. "mg", "mcg", "IU"
  final double amountPerDose;
  final String doseUnit; // e.g. "tablet(s)", "capsule(s)", "ml"
  final String? instructions;
  final bool isActive;
  final bool isAsNeeded;
  final double quantityOnHand;
  final String quantityUnit;
  final bool refillReminderEnabled;
  final double? refillThresholdQty;
  final DateTime? refillReminderDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Medication.create({
    required String userId,
    required String name,
    required double strength,
    required String strengthUnit,
    required double amountPerDose,
    required String doseUnit,
    String? instructions,
    bool isAsNeeded = false,
    double quantityOnHand = 0,
    String quantityUnit = 'tablet(s)',
    bool refillReminderEnabled = false,
    double? refillThresholdQty,
    DateTime? refillReminderDate,
  }) {
    final now = DateTime.now().toUtc();
    return Medication(
      id: _uuid.v4(),
      userId: userId,
      name: name,
      strength: strength,
      strengthUnit: strengthUnit,
      amountPerDose: amountPerDose,
      doseUnit: doseUnit,
      instructions: instructions,
      isActive: true,
      isAsNeeded: isAsNeeded,
      quantityOnHand: quantityOnHand,
      quantityUnit: quantityUnit,
      refillReminderEnabled: refillReminderEnabled,
      refillThresholdQty: refillThresholdQty,
      refillReminderDate: refillReminderDate,
      createdAt: now,
      updatedAt: now,
    );
  }

  Medication copyWith({
    String? name,
    double? strength,
    String? strengthUnit,
    double? amountPerDose,
    String? doseUnit,
    String? instructions,
    bool? isActive,
    bool? isAsNeeded,
    double? quantityOnHand,
    String? quantityUnit,
    bool? refillReminderEnabled,
    double? refillThresholdQty,
    DateTime? refillReminderDate,
  }) {
    return Medication(
      id: id,
      userId: userId,
      name: name ?? this.name,
      strength: strength ?? this.strength,
      strengthUnit: strengthUnit ?? this.strengthUnit,
      amountPerDose: amountPerDose ?? this.amountPerDose,
      doseUnit: doseUnit ?? this.doseUnit,
      instructions: instructions ?? this.instructions,
      isActive: isActive ?? this.isActive,
      isAsNeeded: isAsNeeded ?? this.isAsNeeded,
      quantityOnHand: quantityOnHand ?? this.quantityOnHand,
      quantityUnit: quantityUnit ?? this.quantityUnit,
      refillReminderEnabled: refillReminderEnabled ?? this.refillReminderEnabled,
      refillThresholdQty: refillThresholdQty ?? this.refillThresholdQty,
      refillReminderDate: refillReminderDate ?? this.refillReminderDate,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'strength': strength,
        'strength_unit': strengthUnit,
        'amount_per_dose': amountPerDose,
        'dose_unit': doseUnit,
        'instructions': instructions,
        'is_active': isActive ? 1 : 0,
        'is_as_needed': isAsNeeded ? 1 : 0,
        'quantity_on_hand': quantityOnHand,
        'quantity_unit': quantityUnit,
        'refill_reminder_enabled': refillReminderEnabled ? 1 : 0,
        'refill_threshold_qty': refillThresholdQty,
        'refill_reminder_date': refillReminderDate?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Medication.fromMap(Map<String, dynamic> map) => Medication(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        name: map['name'] as String,
        strength: (map['strength'] as num).toDouble(),
        strengthUnit: map['strength_unit'] as String,
        amountPerDose: (map['amount_per_dose'] as num).toDouble(),
        doseUnit: map['dose_unit'] as String,
        instructions: map['instructions'] as String?,
        isActive: (map['is_active'] as int) == 1,
        isAsNeeded: (map['is_as_needed'] as int?) == 1,
        quantityOnHand: (map['quantity_on_hand'] as num).toDouble(),
        quantityUnit: map['quantity_unit'] as String? ?? 'tablet(s)',
        refillReminderEnabled: (map['refill_reminder_enabled'] as int?) == 1,
        refillThresholdQty: map['refill_threshold_qty'] != null
            ? (map['refill_threshold_qty'] as num).toDouble()
            : null,
        refillReminderDate: map['refill_reminder_date'] != null
            ? DateTime.parse(map['refill_reminder_date'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  String get displayStrength => '${strength.toStringAsFixed(strength.truncateToDouble() == strength ? 0 : 1)} $strengthUnit';
  String get displayDose => '${amountPerDose.toStringAsFixed(amountPerDose.truncateToDouble() == amountPerDose ? 0 : 1)} $doseUnit';

  bool get isLowStock =>
      refillReminderEnabled && refillThresholdQty != null && quantityOnHand <= refillThresholdQty!;
}

// ── Schedule ──────────────────────────────────────────────────────────────────

class MedicationSchedule {
  const MedicationSchedule({
    required this.id,
    required this.medicationId,
    required this.userId,
    required this.timesOfDay,
    required this.frequencyType,
    this.repeatDays,
    required this.startDate,
    this.endDate,
    required this.timezone,
    required this.createdAt,
    this.supersededAt,
  });

  final String id;
  final String medicationId;
  final String userId;
  final List<String> timesOfDay; // "HH:MM"
  final String frequencyType; // 'daily', 'weekly', 'specific_days'
  final List<int>? repeatDays; // 1=Mon..7=Sun
  final DateTime startDate;
  final DateTime? endDate;
  final String timezone;
  final DateTime createdAt;
  final DateTime? supersededAt;

  factory MedicationSchedule.create({
    required String medicationId,
    required String userId,
    required List<String> timesOfDay,
    String frequencyType = 'daily',
    List<int>? repeatDays,
    required DateTime startDate,
    DateTime? endDate,
    required String timezone,
  }) {
    return MedicationSchedule(
      id: _uuid.v4(),
      medicationId: medicationId,
      userId: userId,
      timesOfDay: timesOfDay,
      frequencyType: frequencyType,
      repeatDays: repeatDays,
      startDate: startDate,
      endDate: endDate,
      timezone: timezone,
      createdAt: DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'medication_id': medicationId,
        'user_id': userId,
        'times_of_day': timesOfDay.join(','),
        'frequency_type': frequencyType,
        'repeat_days': repeatDays?.join(','),
        'start_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'timezone': timezone,
        'created_at': createdAt.toIso8601String(),
        'superseded_at': supersededAt?.toIso8601String(),
      };

  factory MedicationSchedule.fromMap(Map<String, dynamic> map) => MedicationSchedule(
        id: map['id'] as String,
        medicationId: map['medication_id'] as String,
        userId: map['user_id'] as String,
        timesOfDay: (map['times_of_day'] as String).split(','),
        frequencyType: map['frequency_type'] as String,
        repeatDays: map['repeat_days'] != null
            ? (map['repeat_days'] as String).split(',').map(int.parse).toList()
            : null,
        startDate: DateTime.parse(map['start_date'] as String),
        endDate: map['end_date'] != null ? DateTime.parse(map['end_date'] as String) : null,
        timezone: map['timezone'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        supersededAt: map['superseded_at'] != null
            ? DateTime.parse(map['superseded_at'] as String)
            : null,
      );
}

// ── DoseOccurrence ────────────────────────────────────────────────────────────

class DoseOccurrence {
  const DoseOccurrence({
    required this.id,
    required this.scheduleId,
    required this.medicationId,
    required this.userId,
    required this.scheduledAt,
    required this.localDate,
    required this.occurrenceKey,
    required this.status,
    required this.createdAt,
    this.snoozeUntil,
  });

  final String id;
  final String scheduleId;
  final String medicationId;
  final String userId;
  final DateTime scheduledAt;
  final String localDate; // 'YYYY-MM-DD'
  final String occurrenceKey; // schedule_id + local_date + time — unique
  final DoseStatus status;
  final DateTime createdAt;
  final DateTime? snoozeUntil;

  DoseOccurrence copyWith({DoseStatus? status, DateTime? snoozeUntil}) => DoseOccurrence(
        id: id,
        scheduleId: scheduleId,
        medicationId: medicationId,
        userId: userId,
        scheduledAt: scheduledAt,
        localDate: localDate,
        occurrenceKey: occurrenceKey,
        status: status ?? this.status,
        createdAt: createdAt,
        snoozeUntil: snoozeUntil ?? this.snoozeUntil,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'schedule_id': scheduleId,
        'medication_id': medicationId,
        'user_id': userId,
        'scheduled_at': scheduledAt.toIso8601String(),
        'local_date': localDate,
        'occurrence_key': occurrenceKey,
        'status': status.toDbString(),
        'created_at': createdAt.toIso8601String(),
        'snooze_until': snoozeUntil?.toIso8601String(),
      };

  factory DoseOccurrence.fromMap(Map<String, dynamic> map) => DoseOccurrence(
        id: map['id'] as String,
        scheduleId: map['schedule_id'] as String,
        medicationId: map['medication_id'] as String,
        userId: map['user_id'] as String,
        scheduledAt: DateTime.parse(map['scheduled_at'] as String),
        localDate: map['local_date'] as String,
        occurrenceKey: map['occurrence_key'] as String,
        status: DoseStatus.fromString(map['status'] as String? ?? 'pending'),
        createdAt: DateTime.parse(map['created_at'] as String),
        snoozeUntil: map['snooze_until'] != null
            ? DateTime.parse(map['snooze_until'] as String)
            : null,
      );
}

// ── DoseEvent ─────────────────────────────────────────────────────────────────

class DoseEvent {
  const DoseEvent({
    required this.id,
    required this.occurrenceId,
    required this.userId,
    required this.action,
    required this.recordedAt,
    this.snoozeUntil,
    this.skipReason,
    required this.clientId,
    required this.createdAt,
  });

  final String id;
  final String occurrenceId;
  final String userId;
  final String action; // 'taken'|'missed'|'skipped'|'snoozed'|'undo'|'correction'
  final DateTime recordedAt;
  final DateTime? snoozeUntil;
  final String? skipReason;
  final String clientId; // idempotency key
  final DateTime createdAt;

  factory DoseEvent.create({
    required String occurrenceId,
    required String userId,
    required String action,
    DateTime? snoozeUntil,
    String? skipReason,
  }) {
    final now = DateTime.now().toUtc();
    return DoseEvent(
      id: _uuid.v4(),
      occurrenceId: occurrenceId,
      userId: userId,
      action: action,
      recordedAt: now,
      snoozeUntil: snoozeUntil,
      skipReason: skipReason,
      clientId: _uuid.v4(),
      createdAt: now,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'occurrence_id': occurrenceId,
        'user_id': userId,
        'action': action,
        'recorded_at': recordedAt.toIso8601String(),
        'snooze_until': snoozeUntil?.toIso8601String(),
        'skip_reason': skipReason,
        'client_id': clientId,
        'created_at': createdAt.toIso8601String(),
      };

  factory DoseEvent.fromMap(Map<String, dynamic> map) => DoseEvent(
        id: map['id'] as String,
        occurrenceId: map['occurrence_id'] as String,
        userId: map['user_id'] as String,
        action: map['action'] as String,
        recordedAt: DateTime.parse(map['recorded_at'] as String),
        snoozeUntil: map['snooze_until'] != null
            ? DateTime.parse(map['snooze_until'] as String)
            : null,
        skipReason: map['skip_reason'] as String?,
        clientId: map['client_id'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

// ── StockEvent ────────────────────────────────────────────────────────────────

class StockEvent {
  const StockEvent({
    required this.id,
    required this.medicationId,
    required this.userId,
    required this.eventType,
    required this.quantityDelta,
    required this.quantityAfter,
    this.doseEventId,
    required this.clientId,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String medicationId;
  final String userId;
  final String eventType; // 'deduction'|'refill'|'correction'
  final double quantityDelta;
  final double quantityAfter;
  final String? doseEventId;
  final String clientId;
  final String? note;
  final DateTime createdAt;

  factory StockEvent.create({
    required String medicationId,
    required String userId,
    required String eventType,
    required double quantityDelta,
    required double quantityAfter,
    String? doseEventId,
    String? note,
  }) {
    final now = DateTime.now().toUtc();
    return StockEvent(
      id: _uuid.v4(),
      medicationId: medicationId,
      userId: userId,
      eventType: eventType,
      quantityDelta: quantityDelta,
      quantityAfter: quantityAfter,
      doseEventId: doseEventId,
      clientId: _uuid.v4(),
      note: note,
      createdAt: now,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'medication_id': medicationId,
        'user_id': userId,
        'event_type': eventType,
        'quantity_delta': quantityDelta,
        'quantity_after': quantityAfter,
        'dose_event_id': doseEventId,
        'client_id': clientId,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory StockEvent.fromMap(Map<String, dynamic> map) => StockEvent(
        id: map['id'] as String,
        medicationId: map['medication_id'] as String,
        userId: map['user_id'] as String,
        eventType: map['event_type'] as String,
        quantityDelta: (map['quantity_delta'] as num).toDouble(),
        quantityAfter: (map['quantity_after'] as num).toDouble(),
        doseEventId: map['dose_event_id'] as String?,
        clientId: map['client_id'] as String,
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

// ── UserProfile ───────────────────────────────────────────────────────────────

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.preferredLanguage = 'en',
    this.textScaleFactor = 1.0,
    this.simpleWording = false,
    this.notificationSound = true,
    this.notificationVibration = true,
    this.privacySafePreviews = true,
  });

  final String id;
  final String fullName;
  final String? avatarUrl;
  final String preferredLanguage;
  final double textScaleFactor;
  final bool simpleWording;
  final bool notificationSound;
  final bool notificationVibration;
  final bool privacySafePreviews;

  UserProfile copyWith({
    String? fullName,
    String? avatarUrl,
    String? preferredLanguage,
    double? textScaleFactor,
    bool? simpleWording,
    bool? notificationSound,
    bool? notificationVibration,
    bool? privacySafePreviews,
  }) =>
      UserProfile(
        id: id,
        fullName: fullName ?? this.fullName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        textScaleFactor: textScaleFactor ?? this.textScaleFactor,
        simpleWording: simpleWording ?? this.simpleWording,
        notificationSound: notificationSound ?? this.notificationSound,
        notificationVibration: notificationVibration ?? this.notificationVibration,
        privacySafePreviews: privacySafePreviews ?? this.privacySafePreviews,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'preferred_language': preferredLanguage,
        'text_scale_factor': textScaleFactor,
        'simple_wording': simpleWording ? 1 : 0,
        'notification_sound': notificationSound ? 1 : 0,
        'notification_vibration': notificationVibration ? 1 : 0,
        'privacy_safe_previews': privacySafePreviews ? 1 : 0,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String,
        fullName: map['full_name'] as String? ?? '',
        avatarUrl: map['avatar_url'] as String?,
        preferredLanguage: map['preferred_language'] as String? ?? 'en',
        textScaleFactor: (map['text_scale_factor'] as num?)?.toDouble() ?? 1.0,
        simpleWording: (map['simple_wording'] as int?) == 1,
        notificationSound: (map['notification_sound'] as int?) != 0,
        notificationVibration: (map['notification_vibration'] as int?) != 0,
        privacySafePreviews: (map['privacy_safe_previews'] as int?) != 0,
      );
}
