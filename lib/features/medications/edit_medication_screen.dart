import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/dd_button.dart';
import '../../core/widgets/dd_card.dart';
import '../../core/widgets/dd_text_field.dart';
import '../../core/widgets/dd_loading.dart';
import '../../data/local/database_provider.dart';
import '../../data/local/models/app_models.dart';
import '../../data/remote/auth_service.dart';
import '../../data/remote/supabase_sync_service.dart';
import '../../data/repositories/app_repositories.dart';
import '../../services/dose_alarm_scheduler.dart';
import '../../services/notification_service.dart';
import '../home/home_dashboard_screen.dart';

final editMedicationProvider =
    FutureProvider.family<Medication?, String>((ref, id) async {
  final repo = ref.watch(medicationRepositoryProvider);
  return repo.getMedicationById(id);
});

final editMedicationScheduleProvider =
    FutureProvider.family<MedicationSchedule?, String>((ref, id) async {
  final repo = ref.watch(medicationRepositoryProvider);
  return repo.getScheduleForMedication(id);
});

class EditMedicationScreen extends ConsumerStatefulWidget {
  const EditMedicationScreen({super.key, required this.medicationId});
  final String medicationId;

  @override
  ConsumerState<EditMedicationScreen> createState() =>
      _EditMedicationScreenState();
}

class _EditMedicationScreenState extends ConsumerState<EditMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _strengthCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _refillThresholdCtrl = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String _strengthUnit = 'mg';
  double _amountPerDose = 1;
  String _doseUnit = 'tablet(s)';
  String _frequencyType = 'daily';
  List<String> _timesOfDay = ['08:00'];
  bool _refillReminderEnabled = false;
  Uint8List? _newImageBytes;
  String _newImageExtension = 'jpg';
  bool _removeExistingImage = false;
  bool _isLoading = false;
  bool _hasChanges = false;
  Medication? _original;
  MedicationSchedule? _originalSchedule;

  static const _strengthUnits = [
    'mg',
    'mcg',
    'g',
    'IU',
    'mmol',
    'mEq',
    '%',
    'ml'
  ];
  static const _doseUnits = [
    'tablet(s)',
    'capsule(s)',
    'ml',
    'drop(s)',
    'patch(es)',
    'unit(s)',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _strengthCtrl.dispose();
    _instructionsCtrl.dispose();
    _quantityCtrl.dispose();
    _refillThresholdCtrl.dispose();
    super.dispose();
  }

  void _populateFrom(Medication med, MedicationSchedule? schedule) {
    if (_original != null) return; // already populated
    _original = med;
    _nameCtrl.text = med.name;
    _strengthCtrl.text = med.strength.toString();
    _strengthUnit = med.strengthUnit;
    _amountPerDose = med.amountPerDose;
    _doseUnit = med.doseUnit;
    _instructionsCtrl.text = med.instructions ?? '';
    _quantityCtrl.text = med.quantityOnHand.toString();
    _refillReminderEnabled = med.refillReminderEnabled;
    _refillThresholdCtrl.text = med.refillThresholdQty?.toString() ?? '';
    _originalSchedule = schedule;
    _frequencyType = schedule?.frequencyType ?? 'daily';
    _timesOfDay = schedule?.timesOfDay.isNotEmpty == true
        ? List<String>.from(schedule!.timesOfDay)
        : ['08:00'];

    // Listen for changes
    for (final ctrl in [
      _nameCtrl,
      _strengthCtrl,
      _instructionsCtrl,
      _quantityCtrl,
      _refillThresholdCtrl,
    ]) {
      ctrl.addListener(() => setState(() => _hasChanges = true));
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Discard them?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Editing')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Discard', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(medicationRepositoryProvider);
      String? imageUrl = _original!.imageUrl;
      if (_newImageBytes != null) {
        imageUrl = await AuthService.uploadMedicationImage(
          medicationId: _original!.id,
          bytes: _newImageBytes!,
          fileExtension: _newImageExtension,
        );
      } else if (_removeExistingImage) {
        imageUrl = null;
      }
      final instructions = _instructionsCtrl.text.trim();
      final refillThreshold = _refillReminderEnabled
          ? double.tryParse(_refillThresholdCtrl.text)
          : null;
      final updated = _original!.copyWith(
        name: _nameCtrl.text.trim(),
        strength: double.tryParse(_strengthCtrl.text) ?? _original!.strength,
        strengthUnit: _strengthUnit,
        amountPerDose: _amountPerDose,
        doseUnit: _doseUnit,
        imageUrl: imageUrl,
        clearImageUrl: imageUrl == null,
        instructions: instructions.isEmpty ? null : instructions,
        clearInstructions: instructions.isEmpty,
        quantityOnHand:
            double.tryParse(_quantityCtrl.text) ?? _original!.quantityOnHand,
        quantityUnit: _doseUnit,
        refillReminderEnabled: _refillReminderEnabled,
        refillThresholdQty: refillThreshold,
        clearRefillThresholdQty: refillThreshold == null,
      );
      await repo.updateMedication(updated);
      await _saveSchedule(updated);
      await DoseAlarmScheduler.syncUpcomingAlarms();
      ref.invalidate(allActiveMedsProvider);
      ref.invalidate(todayOccurrencesProvider);
      ref.invalidate(todayMedicationsProvider);
      ref.invalidate(editMedicationProvider(widget.medicationId));
      ref.invalidate(editMedicationScheduleProvider(widget.medicationId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medication updated')),
      );
      setState(() => _hasChanges = false);
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSchedule(Medication medication) async {
    final database = await ref.read(appDatabaseProvider).database;
    final now = DateTime.now();
    final nowUtc = now.toUtc();
    final localDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final scheduleId = _originalSchedule?.id ?? const Uuid().v4();
    final timezone =
        _originalSchedule?.timezone ?? await FlutterTimezone.getLocalTimezone();
    final startDate =
        _originalSchedule?.startDate ?? DateTime(now.year, now.month, now.day);

    try {
      await SupabaseSyncService.deleteOpenOccurrencesForSchedule(
        scheduleId: scheduleId,
        fromLocalDate: localDate,
      );
    } catch (_) {
      // The local edit remains available offline; the next sync can retry.
    }
    final obsoleteOccurrences = await database.query(
      'dose_occurrences',
      columns: ['id'],
      where: 'schedule_id = ? AND local_date >= ? AND status IN (?, ?, ?)',
      whereArgs: [
        scheduleId,
        localDate,
        'pending',
        'snoozed',
        'overdue',
      ],
    );
    for (final occurrence in obsoleteOccurrences) {
      await NotificationService.cancelDoseAlarm(occurrence['id'] as String);
    }
    await database.delete(
      'dose_occurrences',
      where: 'schedule_id = ? AND local_date >= ? AND status IN (?, ?, ?)',
      whereArgs: [
        scheduleId,
        localDate,
        'pending',
        'snoozed',
        'overdue',
      ],
    );

    final scheduleData = <String, dynamic>{
      'id': scheduleId,
      'medication_id': medication.id,
      'user_id': medication.userId,
      'times_of_day': _timesOfDay.join(','),
      'frequency_type': _frequencyType,
      'repeat_days': _originalSchedule?.repeatDays?.join(','),
      'start_date': startDate.toIso8601String(),
      'end_date': _originalSchedule?.endDate?.toIso8601String(),
      'timezone': timezone,
      'created_at': (_originalSchedule?.createdAt ?? nowUtc).toIso8601String(),
      'superseded_at': null,
    };
    await database.insert(
      'schedules',
      scheduleData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    SupabaseSyncService.pushSchedule({
      ...scheduleData,
      'times_of_day': _timesOfDay,
      'repeat_days': _originalSchedule?.repeatDays,
    }).ignore();

    for (final timeText in _timesOfDay) {
      final parts = timeText.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts.first);
      final minute = int.tryParse(parts.last);
      if (hour == null || minute == null) continue;
      final scheduledAt =
          DateTime(now.year, now.month, now.day, hour, minute).toUtc();
      final occurrenceData = <String, dynamic>{
        'id': const Uuid().v4(),
        'schedule_id': scheduleId,
        'medication_id': medication.id,
        'user_id': medication.userId,
        'scheduled_at': scheduledAt.toIso8601String(),
        'local_date': localDate,
        'occurrence_key': '$scheduleId-$localDate-$timeText',
        'status': 'pending',
        'created_at': nowUtc.toIso8601String(),
      };
      await database.insert(
        'dose_occurrences',
        occurrenceData,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      SupabaseSyncService.pushDoseOccurrence(occurrenceData).ignore();
    }
  }

  Future<void> _pickTime(int index) async {
    final parts = _timesOfDay[index].split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 8,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    setState(() {
      final updated = List<String>.from(_timesOfDay);
      updated[index] =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _timesOfDay = updated;
      _hasChanges = true;
    });
  }

  Future<void> _pickMedicationImage(ImageSource source) async {
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 82,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _newImageBytes = bytes;
        _newImageExtension = file.name.contains('.')
            ? file.name.split('.').last.toLowerCase()
            : 'jpg';
        _removeExistingImage = false;
        _hasChanges = true;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update image: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showMedicationImageOptions() {
    final hasImage = _newImageBytes != null ||
        (!_removeExistingImage &&
            (_original?.imageUrl?.trim().isNotEmpty ?? false));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Medication image', style: AppTextStyles.headlineMd()),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickMedicationImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickMedicationImage(ImageSource.gallery);
              },
            ),
            if (hasImage)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                title: const Text('Remove image'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() {
                    _newImageBytes = null;
                    _removeExistingImage = true;
                    _hasChanges = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  static String _formatDoseAmount(double value) {
    return value.toStringAsFixed(
      value.truncateToDouble() == value ? 0 : 1,
    );
  }

  static String _formatTime(String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final time = TimeOfDay(hour: hour, minute: minute);
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final displayHour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Medication'),
        content: Text(
          'Are you sure you want to delete ${_original?.name}?\n\nFuture reminders will be cancelled. Past dose history is preserved.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final database = await ref.read(appDatabaseProvider).database;
      final openOccurrences = await database.query(
        'dose_occurrences',
        columns: ['id'],
        where: 'medication_id = ? AND status IN (?, ?, ?)',
        whereArgs: [
          widget.medicationId,
          'pending',
          'snoozed',
          'overdue',
        ],
      );
      for (final occurrence in openOccurrences) {
        await NotificationService.cancelDoseAlarm(occurrence['id'] as String);
      }
      await ref
          .read(medicationRepositoryProvider)
          .archiveMedication(widget.medicationId);
      ref.invalidate(allActiveMedsProvider);
      ref.invalidate(todayOccurrencesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Medication deleted. Past records preserved.')),
      );
      setState(() => _hasChanges = false);
      context.pop();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final medAsync = ref.watch(editMedicationProvider(widget.medicationId));
    final scheduleAsync =
        ref.watch(editMedicationScheduleProvider(widget.medicationId));

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          setState(() => _hasChanges = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          title: const Text('Edit Medication'),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: _original != null ? _delete : null,
              tooltip: 'Delete',
            ),
          ],
        ),
        body: medAsync.when(
          loading: () => const DdLoadingScreen(message: 'Loading...'),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (med) {
            if (med == null) {
              return const Center(child: Text('Medication not found'));
            }
            if (scheduleAsync is AsyncLoading<MedicationSchedule?>) {
              return const DdLoading();
            }
            _populateFrom(med, scheduleAsync.valueOrNull);
            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  AppDimensions.screenMargin,
                  AppDimensions.screenMargin,
                  AppDimensions.screenMargin,
                  AppDimensions.navBarHeight +
                      MediaQuery.paddingOf(context).bottom +
                      AppDimensions.stack2Xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Details', style: AppTextStyles.headlineMd()),
                    const SizedBox(height: AppDimensions.stackLg),
                    InkWell(
                      onTap: _showMedicationImageOptions,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.cardRadius),
                      child: Ink(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.cardRadius),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.cardRadius),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_newImageBytes != null)
                                Image.memory(
                                  _newImageBytes!,
                                  fit: BoxFit.cover,
                                )
                              else
                                _EditableMedicationImage(
                                  imageUrl: _removeExistingImage
                                      ? null
                                      : med.imageUrl,
                                ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  color: Colors.black54,
                                  child: const Text(
                                    'Tap to change medication image',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.stackLg),
                    DdTextField(
                      label: 'Medicine name *',
                      controller: _nameCtrl,
                      validator: (v) =>
                          v?.trim().isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: AppDimensions.stackLg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: DdTextField(
                            label: 'Strength',
                            controller: _strengthCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.stackMd),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Unit', style: AppTextStyles.bodyBold()),
                              const SizedBox(height: AppDimensions.stackSm),
                              DropdownButtonFormField<String>(
                                value: _strengthUnit,
                                items: _strengthUnits
                                    .map((u) => DropdownMenuItem(
                                        value: u, child: Text(u)))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _strengthUnit = v!;
                                  _hasChanges = true;
                                }),
                                decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.stackLg),
                    Text('Amount per dose', style: AppTextStyles.bodyBold()),
                    const SizedBox(height: AppDimensions.stackSm),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _amountPerDose > 0.5
                                    ? () => setState(() {
                                          _amountPerDose -= 0.5;
                                          _hasChanges = true;
                                        })
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                                color: AppColors.primaryAction,
                                iconSize: 32,
                              ),
                              Expanded(
                                child: Text(
                                  _formatDoseAmount(_amountPerDose),
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.headlineMd(),
                                ),
                              ),
                              IconButton(
                                onPressed: () => setState(() {
                                  _amountPerDose += 0.5;
                                  _hasChanges = true;
                                }),
                                icon: const Icon(Icons.add_circle_outline),
                                color: AppColors.primaryAction,
                                iconSize: 32,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppDimensions.stackMd),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _doseUnits.contains(_doseUnit)
                                ? _doseUnit
                                : _doseUnits.first,
                            isExpanded: true,
                            items: _doseUnits
                                .map((unit) => DropdownMenuItem(
                                      value: unit,
                                      child: Text(unit),
                                    ))
                                .toList(),
                            onChanged: (value) => setState(() {
                              _doseUnit = value!;
                              _hasChanges = true;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.stackLg),
                    DdTextField(
                      label: 'Instructions',
                      controller: _instructionsCtrl,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppDimensions.stackXl),
                    Text('Schedule', style: AppTextStyles.headlineMd()),
                    const SizedBox(height: AppDimensions.stackLg),
                    Text('Frequency', style: AppTextStyles.bodyBold()),
                    const SizedBox(height: AppDimensions.stackSm),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'daily',
                          label: Text('Daily'),
                        ),
                        ButtonSegment(
                          value: 'weekly',
                          label: Text('Weekly'),
                        ),
                        ButtonSegment(
                          value: 'specific_days',
                          label: Text('Specific'),
                        ),
                      ],
                      selected: {_frequencyType},
                      onSelectionChanged: (selection) => setState(() {
                        _frequencyType = selection.first;
                        _hasChanges = true;
                      }),
                    ),
                    const SizedBox(height: AppDimensions.stackLg),
                    Text('Reminder times', style: AppTextStyles.bodyBold()),
                    const SizedBox(height: AppDimensions.stackSm),
                    for (var index = 0; index < _timesOfDay.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppDimensions.stackSm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickTime(index),
                                icon: const Icon(Icons.access_time),
                                label: Text(
                                  _formatTime(_timesOfDay[index]),
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 52),
                                  alignment: Alignment.centerLeft,
                                ),
                              ),
                            ),
                            if (_timesOfDay.length > 1) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: AppColors.error,
                                ),
                                onPressed: () => setState(() {
                                  _timesOfDay = List<String>.from(_timesOfDay)
                                    ..removeAt(index);
                                  _hasChanges = true;
                                }),
                              ),
                            ],
                          ],
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _timesOfDay = [..._timesOfDay, '12:00'];
                        _hasChanges = true;
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('Add another time'),
                    ),
                    const SizedBox(height: AppDimensions.stackXl),
                    Text('Stock & Refills', style: AppTextStyles.headlineMd()),
                    const SizedBox(height: AppDimensions.stackLg),
                    DdTextField(
                      label: 'Current quantity',
                      controller: _quantityCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: AppDimensions.stackLg),
                    DdCard(
                      padding:
                          const EdgeInsets.all(AppDimensions.cardPaddingSm),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Refill reminder',
                                  style: AppTextStyles.bodyBold(),
                                ),
                                Text(
                                  'Get notified when stock runs low',
                                  style: AppTextStyles.caption(),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _refillReminderEnabled,
                            onChanged: (value) => setState(() {
                              _refillReminderEnabled = value;
                              _hasChanges = true;
                            }),
                          ),
                        ],
                      ),
                    ),
                    if (_refillReminderEnabled) ...[
                      const SizedBox(height: AppDimensions.stackMd),
                      DdTextField(
                        label: 'Low-stock threshold (units)',
                        controller: _refillThresholdCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        helperText: 'Remind me when I have this many left',
                      ),
                    ],
                    const SizedBox(height: AppDimensions.stack2Xl),
                    Row(
                      children: [
                        Expanded(
                          child: DdButton(
                            label: 'Cancel',
                            onPressed: () async {
                              final shouldPop = await _onWillPop();
                              if (shouldPop && context.mounted) {
                                setState(() => _hasChanges = false);
                                context.pop();
                              }
                            },
                            variant: DdButtonVariant.secondary,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.stackMd),
                        Expanded(
                          flex: 2,
                          child: DdButton(
                            label: 'Save Changes',
                            onPressed: _save,
                            isLoading: _isLoading,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.stackXl),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EditableMedicationImage extends StatelessWidget {
  const _EditableMedicationImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final image = _buildImage();
    if (image != null) return image;
    return Container(
      color: AppColors.pendingBackground,
      alignment: Alignment.center,
      child: Icon(
        Icons.add_photo_alternate_outlined,
        size: 42,
        color: AppColors.primaryAction,
      ),
    );
  }

  Widget? _buildImage() {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        final separator = url.indexOf(',');
        if (separator < 0) return null;
        return Image.memory(
          base64Decode(url.substring(separator + 1)),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      } catch (_) {
        return null;
      }
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return null;
  }
}
