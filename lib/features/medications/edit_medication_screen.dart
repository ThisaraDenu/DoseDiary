import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/dd_button.dart';
import '../../core/widgets/dd_text_field.dart';
import '../../core/widgets/dd_loading.dart';
import '../../data/local/models/app_models.dart';
import '../../data/repositories/app_repositories.dart';
import '../home/home_dashboard_screen.dart';

final editMedicationProvider = FutureProvider.family<Medication?, String>((ref, id) async {
  final repo = ref.watch(medicationRepositoryProvider);
  return repo.getMedicationById(id);
});

class EditMedicationScreen extends ConsumerStatefulWidget {
  const EditMedicationScreen({super.key, required this.medicationId});
  final String medicationId;

  @override
  ConsumerState<EditMedicationScreen> createState() => _EditMedicationScreenState();
}

class _EditMedicationScreenState extends ConsumerState<EditMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _strengthCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  String _strengthUnit = 'mg';
  double _amountPerDose = 1;
  String _doseUnit = 'tablet(s)';
  bool _refillReminderEnabled = false;
  bool _isLoading = false;
  bool _hasChanges = false;
  Medication? _original;

  static const _strengthUnits = ['mg', 'mcg', 'g', 'IU', 'mmol', 'mEq', '%', 'ml'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _strengthCtrl.dispose();
    _instructionsCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  void _populateFrom(Medication med) {
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

    // Listen for changes
    for (final ctrl in [_nameCtrl, _strengthCtrl, _instructionsCtrl, _quantityCtrl]) {
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Editing')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: AppColors.error)),
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
      final updated = _original!.copyWith(
        name: _nameCtrl.text.trim(),
        strength: double.tryParse(_strengthCtrl.text) ?? _original!.strength,
        strengthUnit: _strengthUnit,
        amountPerDose: _amountPerDose,
        doseUnit: _doseUnit,
        instructions: _instructionsCtrl.text.trim().isEmpty ? null : _instructionsCtrl.text.trim(),
        quantityOnHand: double.tryParse(_quantityCtrl.text) ?? _original!.quantityOnHand,
        refillReminderEnabled: _refillReminderEnabled,
      );
      await repo.updateMedication(updated);
      ref.invalidate(allActiveMedsProvider);
      ref.invalidate(todayOccurrencesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medication updated')),
      );
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(medicationRepositoryProvider).archiveMedication(widget.medicationId);
      ref.invalidate(allActiveMedsProvider);
      ref.invalidate(todayOccurrencesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medication deleted. Past records preserved.')),
      );
      context.pop();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final medAsync = ref.watch(editMedicationProvider(widget.medicationId));

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
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
            if (med == null) return const Center(child: Text('Medication not found'));
            _populateFrom(med);
            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.screenMargin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Details', style: AppTextStyles.headlineMd()),
                    const SizedBox(height: AppDimensions.stackLg),
                    DdTextField(
                      label: 'Medicine name *',
                      controller: _nameCtrl,
                      validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _strengthUnit = v!;
                                  _hasChanges = true;
                                }),
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                              ),
                            ],
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
                    const SizedBox(height: AppDimensions.stackLg),
                    DdTextField(
                      label: 'Current quantity',
                      controller: _quantityCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: AppDimensions.stack2Xl),
                    Row(
                      children: [
                        Expanded(
                          child: DdButton(
                            label: 'Cancel',
                            onPressed: () async {
                              final shouldPop = await _onWillPop();
                              if (shouldPop && context.mounted) context.pop();
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
