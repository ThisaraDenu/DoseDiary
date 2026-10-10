import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:uuid/uuid.dart';
// Local imports

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/dd_button.dart';
import '../../core/widgets/dd_text_field.dart';
import '../../core/widgets/dd_card.dart';
import '../../data/local/database_provider.dart';
import '../../data/local/models/app_models.dart';
import '../../data/repositories/app_repositories.dart';
import '../../data/remote/auth_service.dart';
import '../../data/remote/supabase_sync_service.dart';
import '../../services/dose_alarm_scheduler.dart';
import '../home/home_dashboard_screen.dart';
// End local imports

const _uuid = Uuid();
// Screen for adding a new medication
class AddMedicationScreen extends ConsumerStatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  ConsumerState<AddMedicationScreen> createState() =>
      _AddMedicationScreenState();
}

class _AddMedicationScreenState extends ConsumerState<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _strengthCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _refillThresholdCtrl = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  // State
  String _strengthUnit = 'mg';
  double _amountPerDose = 1;
  String _doseUnit = 'tablet(s)';
  String _frequencyType = 'daily';
  List<String> _timesOfDay = ['08:00'];
  bool _refillReminderEnabled = false;
  bool _isLoading = false;
  Uint8List? _medicationImageBytes;
  String _medicationImageExtension = 'jpg';

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
    'unit(s)'
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
// Save the medication and create a schedule
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      final medRepo = ref.read(medicationRepositoryProvider);
      final userId = AuthService.currentUser?.id ?? 'guest-user';

      var med = Medication.create(
        userId: userId,
        name: _nameCtrl.text.trim(),
        strength: double.tryParse(_strengthCtrl.text) ?? 0,
        strengthUnit: _strengthUnit,
        amountPerDose: _amountPerDose,
        doseUnit: _doseUnit,
        instructions: _instructionsCtrl.text.trim().isEmpty
            ? null
            : _instructionsCtrl.text.trim(),
        quantityOnHand: double.tryParse(_quantityCtrl.text) ?? 0,
        quantityUnit: _doseUnit,
        refillReminderEnabled: _refillReminderEnabled,
        refillThresholdQty:
            _refillReminderEnabled && _refillThresholdCtrl.text.isNotEmpty
                ? double.tryParse(_refillThresholdCtrl.text)
                : null,
      );
      // Insert the medication into the database

      if (_medicationImageBytes != null) {
        final imageUrl = await AuthService.uploadMedicationImage(
          medicationId: med.id,
          bytes: _medicationImageBytes!,
          fileExtension: _medicationImageExtension,
        );
        med = med.copyWith(imageUrl: imageUrl);
      }

      await medRepo.insertMedication(med);

      // Create a schedule
      final scheduleRepo = ref.read(appDatabaseProvider);
      final db = await scheduleRepo.database;
      final schedId = _uuid.v4();
      final now = DateTime.now().toUtc();
      final today = DateTime(now.year, now.month, now.day);

      final scheduleData = {
        'id': schedId,
        'medication_id': med.id,
        'user_id': userId,
        'times_of_day': _timesOfDay.join(','),
        'frequency_type': _frequencyType,
        'start_date': today.toIso8601String(),
        'timezone': timezone,
        'created_at': now.toIso8601String(),
      };
      await db.insert('schedules', scheduleData);
      SupabaseSyncService.pushSchedule({
        ...scheduleData,
        'times_of_day': _timesOfDay,
      }).ignore();

      // Generate today's occurrences
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      for (final timeStr in _timesOfDay) {
        final parts = timeStr.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final scheduled =
            DateTime(today.year, today.month, today.day, h, m).toUtc();

        final occData = {
          'id': _uuid.v4(),
          'schedule_id': schedId,
          'medication_id': med.id,
          'user_id': userId,
          'scheduled_at': scheduled.toIso8601String(),
          'local_date': todayStr,
          'occurrence_key': '$schedId-$todayStr-$timeStr',
          'status': 'pending',
          'created_at': now.toIso8601String(),
        };
        await db.insert('dose_occurrences', occData,
            conflictAlgorithm: ConflictAlgorithm.ignore);
        SupabaseSyncService.pushDoseOccurrence(occData).ignore();
      }
      await DoseAlarmScheduler.syncUpcomingAlarms();

      // Invalidate providers
      ref.invalidate(todayOccurrencesProvider);
      ref.invalidate(allActiveMedsProvider);
      ref.invalidate(todayMedicationsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${med.name} added successfully')),
      );
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
  // Pick a time for the reminder

  Future<void> _pickTime(int index) async {
    final parts = _timesOfDay[index].split(':');
    final initial =
        TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        final list = List<String>.from(_timesOfDay);
        list[index] =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        _timesOfDay = list;
      });
    }
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
        _medicationImageBytes = bytes;
        _medicationImageExtension = file.name.contains('.')
            ? file.name.split('.').last.toLowerCase()
            : 'jpg';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not add image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showMedicationImageOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Medication image', style: AppTextStyles.headlineMd()),
              const SizedBox(height: AppDimensions.stackSm),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickMedicationImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickMedicationImage(ImageSource.gallery);
                },
              ),
              if (_medicationImageBytes != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                  title: const Text('Remove image'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    setState(() => _medicationImageBytes = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(title: const Text('Add Medication')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            AppDimensions.screenMargin,
            AppDimensions.screenMargin,
            AppDimensions.screenMargin,
            AppDimensions.navBarHeight +
                MediaQuery.paddingOf(context).bottom +
                AppDimensions.stackXl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medication details section
              Text('Medication Details', style: AppTextStyles.headlineMd()),
              const SizedBox(height: AppDimensions.stackLg),

              Semantics(
                button: true,
                label: _medicationImageBytes == null
                    ? 'Add medication image'
                    : 'Change medication image',
                child: InkWell(
                  onTap: _showMedicationImageOptions,
                  borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                  child: Ink(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.cardRadius),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: _medicationImageBytes == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 40,
                                color: AppColors.primaryAction,
                              ),
                              const SizedBox(height: AppDimensions.stackSm),
                              Text(
                                'Add medication image',
                                style: AppTextStyles.bodyBold(),
                              ),
                              Text(
                                'Take a photo or choose from gallery',
                                style: AppTextStyles.caption(),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.cardRadius - 1,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(
                                  _medicationImageBytes!,
                                  fit: BoxFit.cover,
                                ),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: double.infinity,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    color: Colors.black54,
                                    child: const Text(
                                      'Tap to change image',
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
              ),
              const SizedBox(height: AppDimensions.stackLg),

              DdTextField(
                label: 'Medicine name *',
                hint: 'e.g. Metformin',
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                validator: (v) => (v?.trim().isEmpty ?? true)
                    ? 'Medicine name is required'
                    : null,
              ),
              const SizedBox(height: AppDimensions.stackLg),

              // Strength row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: DdTextField(
                      label: 'Strength *',
                      hint: 'e.g. 500',
                      controller: _strengthCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) return 'Required';
                        if (double.tryParse(v!) == null) {
                          return 'Enter a number';
                        }
                        return null;
                      },
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
                              .map((u) =>
                                  DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) => setState(() => _strengthUnit = v!),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.stackLg),

              // Amount per dose row
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount per dose', style: AppTextStyles.bodyBold()),
                  const SizedBox(height: AppDimensions.stackSm),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _amountPerDose > 0.5
                                  ? () => setState(() => _amountPerDose -= 0.5)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                              iconSize: 32,
                              color: AppColors.primaryAction,
                              tooltip: 'Decrease',
                            ),
                            Expanded(
                              child: Text(
                                _amountPerDose.toStringAsFixed(
                                  _amountPerDose.truncateToDouble() ==
                                          _amountPerDose
                                      ? 0
                                      : 1,
                                ),
                                style: AppTextStyles.headlineMd(),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  setState(() => _amountPerDose += 0.5),
                              icon: const Icon(Icons.add_circle_outline),
                              iconSize: 32,
                              color: AppColors.primaryAction,
                              tooltip: 'Increase',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppDimensions.stackMd),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _doseUnit,
                          isExpanded: true,
                          items: _doseUnits
                              .map((u) =>
                                  DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) => setState(() => _doseUnit = v!),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.stackLg),

              DdTextField(
                label: 'Instructions',
                hint: 'e.g. Take with food',
                controller: _instructionsCtrl,
                maxLines: 2,
              ),
              const SizedBox(height: AppDimensions.stackXl),

              // Schedule section
              Text('Schedule', style: AppTextStyles.headlineMd()),
              const SizedBox(height: AppDimensions.stackLg),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Frequency', style: AppTextStyles.bodyBold()),
                  const SizedBox(height: AppDimensions.stackSm),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'daily', label: Text('Daily')),
                      ButtonSegment(value: 'weekly', label: Text('Weekly')),
                      ButtonSegment(
                          value: 'specific_days', label: Text('Specific')),
                    ],
                    selected: {_frequencyType},
                    onSelectionChanged: (s) =>
                        setState(() => _frequencyType = s.first),
                    style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: AppColors.primaryAction),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.stackLg),

              // Times
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reminder times', style: AppTextStyles.bodyBold()),
                  const SizedBox(height: AppDimensions.stackSm),
                  for (int i = 0; i < _timesOfDay.length; i++)
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppDimensions.stackSm),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickTime(i),
                              icon: const Icon(Icons.access_time),
                              label: Text(_formatTime(_timesOfDay[i])),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                alignment: Alignment.centerLeft,
                              ),
                            ),
                          ),
                          if (_timesOfDay.length > 1) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: AppColors.error),
                              onPressed: () {
                                final list = List<String>.from(_timesOfDay)
                                  ..removeAt(i);
                                setState(() => _timesOfDay = list);
                              },
                              tooltip: 'Remove time',
                            ),
                          ],
                        ],
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _timesOfDay = [..._timesOfDay, '12:00']),
                    icon: const Icon(Icons.add),
                    label: const Text('Add another time'),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.stackXl),

              // Stock section
              Text('Stock & Refills', style: AppTextStyles.headlineMd()),
              const SizedBox(height: AppDimensions.stackLg),

              DdTextField(
                label: 'Starting quantity',
                hint: 'e.g. 30',
                controller: _quantityCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppDimensions.stackLg),

              DdCard(
                padding: const EdgeInsets.all(AppDimensions.cardPaddingSm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Refill reminder',
                              style: AppTextStyles.bodyBold()),
                          Text(
                            'Get notified when stock runs low',
                            style: AppTextStyles.caption(),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _refillReminderEnabled,
                      onChanged: (v) =>
                          setState(() => _refillReminderEnabled = v),
                    ),
                  ],
                ),
              ),
              if (_refillReminderEnabled) ...[
                const SizedBox(height: AppDimensions.stackMd),
                DdTextField(
                  label: 'Low-stock threshold (units)',
                  hint: 'e.g. 7',
                  controller: _refillThresholdCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  helperText: 'Remind me when I have this many left',
                ),
              ],
              const SizedBox(height: AppDimensions.stack2Xl),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: DdButton(
                      label: 'Cancel',
                      onPressed: () => context.pop(),
                      variant: DdButtonVariant.secondary,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.stackMd),
                  Expanded(
                    flex: 2,
                    child: DdButton(
                        label: 'Save Medication',
                        onPressed: _save,
                        isLoading: _isLoading),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.stackXl),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final tod = TimeOfDay(hour: h, minute: m);
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    final displayH = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    return '$displayH:${m.toString().padLeft(2, '0')} $period';
  }
}
