import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/local/models/app_models.dart';
import '../../data/local/models/dose_status.dart';
import '../../data/repositories/app_repositories.dart';
import '../../l10n/app_localizations.dart';

/// A dialog for adding or editing a history entry (dose occurrence).

class HistoryEntryEditor extends ConsumerStatefulWidget {
  const HistoryEntryEditor({
    super.key,
    required this.medications,
    required this.initialDate,
    this.occurrence,
    this.event,
  });
// The list of medications to choose from.
  final List<Medication> medications;
  final DateTime initialDate;
  final DoseOccurrence? occurrence;
  final DoseEvent? event;
  // Creates a state for the history entry editor.

  @override
  ConsumerState<HistoryEntryEditor> createState() => _HistoryEntryEditorState();
}
// The state for the history entry editor.
class _HistoryEntryEditorState extends ConsumerState<HistoryEntryEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reason;
  late String _medicationId;
  late DateTime _doseTime;
  late DoseStatus _status;
  bool _saving = false;
  String? _error;
  // Initializes the state of the history entry editor.

  @override
  void initState() {
    super.initState();
    _medicationId =
        widget.occurrence?.medicationId ?? widget.medications.first.id;
    _status = widget.occurrence?.status.isTerminal == true
        ? widget.occurrence!.status
        : DoseStatus.taken;
    final now = DateTime.now();
    _doseTime = (widget.event?.recordedAt ??
            widget.occurrence?.scheduledAt ??
            DateTime(widget.initialDate.year, widget.initialDate.month,
                widget.initialDate.day, now.hour, now.minute))
        .toLocal();
    if (_doseTime.isAfter(now)) _doseTime = now;
    _reason = TextEditingController(text: widget.event?.skipReason ?? '');
  }
// Disposes of the text editing controller when the widget is removed from the tree.
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _doseTime,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    setState(() => _doseTime = DateTime(
        date.year, date.month, date.day, _doseTime.hour, _doseTime.minute));
  }
// Shows a time picker dialog and updates the dose time if a time is selected.
  Future<void> _chooseTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_doseTime),
    );
    if (time == null || !mounted) return;
    setState(() => _doseTime = DateTime(_doseTime.year, _doseTime.month,
        _doseTime.day, time.hour, time.minute));
  }
// Saves the history entry to the repository and handles any errors that may occur.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_doseTime.isAfter(DateTime.now())) {
      setState(() => _error = 'Choose a date and time in the past.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(doseRepositoryProvider).saveHistoryEntry(
            medicationId: _medicationId,
            doseTime: _doseTime,
            status: _status,
            occurrenceId: widget.occurrence?.id,
            skipReason: _reason.text,
          );
      if (mounted) Navigator.pop(context, _doseTime);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save history. Try again.';
        });
      }
    }
  }
// Builds the widget tree for the history entry editor dialog.
  @override
  Widget build(BuildContext context) {
    final editing = widget.occurrence != null;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(context.tr(editing ? 'Edit history' : 'Add past dose')),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    key: const ValueKey('history-medication'),
                    value: _medicationId,
                    isExpanded: true,
                    decoration:
                        InputDecoration(labelText: context.tr('Medication')),
                    items: [
                      for (final medication in widget.medications)
                        DropdownMenuItem(
                          value: medication.id,
                          child: Text(
                              '${medication.name} ${medication.displayStrength}',
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: editing || _saving
                        ? null
                        : (value) => setState(() => _medicationId = value!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<DoseStatus>(
                    key: const ValueKey('history-status'),
                    value: _status,
                    decoration:
                        InputDecoration(labelText: context.tr('Status')),
                    items: [
                      for (final status in [
                        DoseStatus.taken,
                        DoseStatus.skipped,
                        DoseStatus.missed
                      ])
                        DropdownMenuItem(
                          value: status,
                          child: Text(context.tr(
                              '${status.name[0].toUpperCase()}${status.name.substring(1)}')),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _status = value!),
                  ),
                  const SizedBox(height: 12),
                  Text(context.tr(_status == DoseStatus.taken
                      ? 'Time taken'
                      : 'Dose date and time')),
                  ListTile(
                    key: const ValueKey('history-dose-date'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(DateFormat('d MMM yyyy').format(_doseTime)),
                    onTap: _saving ? null : _chooseDate,
                  ),
                  ListTile(
                    key: const ValueKey('history-dose-time'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time),
                    title: Text(DateFormat('h:mm a').format(_doseTime)),
                    onTap: _saving ? null : _chooseTime,
                  ),
                  if (_status == DoseStatus.skipped)
                    TextFormField(
                      key: const ValueKey('history-skip-reason'),
                      controller: _reason,
                      enabled: !_saving,
                      maxLength: 250,
                      decoration: InputDecoration(
                          labelText: context.tr('Skip reason (optional)')),
                    ),
                  if (_error != null)
                    Text(context.tr(_error!),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            key: const ValueKey('save-history-entry'),
            onPressed: _saving ? null : _save,
            child: Text(context.tr(_saving ? 'Saving...' : 'Save')),
          ),
        ],
      ),
    );
  }
}
