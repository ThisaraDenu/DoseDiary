import 'dart:io';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/local/models/app_models.dart';
import '../../data/local/models/dose_status.dart';

enum HistoryPdfPeriod { day, week }

class HistoryPdfService {
  const HistoryPdfService._();

  static Future<String?> export({
    required HistoryPdfPeriod period,
    required DateTime selectedDate,
    required List<DoseOccurrence> occurrences,
    required Map<String, Medication> medications,
    required Map<String, DoseEvent> latestEvents,
  }) async {
    final bytes = await build(
      period: period,
      selectedDate: selectedDate,
      occurrences: occurrences,
      medications: medications,
      latestEvents: latestEvents,
    );
    final date = DateFormat('yyyy-MM-dd').format(selectedDate);
    return FileSaver.instance.saveAs(
      name: 'DoseDiary-${period.name}-history-$date',
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
      initialDirectory:
          Platform.isAndroid ? '/storage/emulated/0/Download' : null,
    );
  }

  static Future<Uint8List> build({
    required HistoryPdfPeriod period,
    required DateTime selectedDate,
    required List<DoseOccurrence> occurrences,
    required Map<String, Medication> medications,
    required Map<String, DoseEvent> latestEvents,
  }) async {
    final end =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final start = period == HistoryPdfPeriod.day
        ? end
        : end.subtract(const Duration(days: 6));
    final selected = occurrences.where((item) {
      final parsed = DateTime.tryParse(item.localDate);
      if (parsed == null) return false;
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      return !day.isBefore(start) && !day.isAfter(end);
    }).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final taken =
        selected.where((item) => item.status == DoseStatus.taken).length;
    final percentage =
        selected.isEmpty ? 0 : (taken / selected.length * 100).round();
    final grouped = <String, List<DoseOccurrence>>{};
    for (final item in selected) {
      grouped.putIfAbsent(item.localDate, () => []).add(item);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final document = pw.Document(
      title: 'DoseDiary Medication History',
      author: 'DoseDiary',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'DoseDiary',
                style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Medication History',
                style: const pw.TextStyle(color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 18),
          pw.Text(
            period == HistoryPdfPeriod.day ? 'Daily History' : 'Weekly History',
            style: const pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            period == HistoryPdfPeriod.day
                ? DateFormat('EEEE, d MMMM yyyy').format(end)
                : '${DateFormat('d MMM yyyy').format(start)} - '
                    '${DateFormat('d MMM yyyy').format(end)}',
            style: const pw.TextStyle(color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 18),
          _summary(taken, selected.length, percentage),
          pw.SizedBox(height: 22),
          if (selected.isEmpty)
            _emptyState()
          else
            for (final day in days) ...[
              _daySection(day, grouped[day]!, medications, latestEvents),
              pw.SizedBox(height: 16),
            ],
        ],
      ),
    );
    return document.save();
  }

  static pw.Widget _summary(int taken, int total, int percentage) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#EAF7F2'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _metric('$percentage%', 'Adherence'),
          _metric('$taken', 'Taken'),
          _metric('$total', 'Scheduled'),
        ],
      ),
    );
  }

  static pw.Widget _metric(String value, String label) => pw.Column(
        children: [
          pw.Text(
            value,
            style: const pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      );

  static pw.Widget _emptyState() => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(18),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text('No medication records were found for this period.'),
      );

  static pw.Widget _daySection(
    String day,
    List<DoseOccurrence> occurrences,
    Map<String, Medication> medications,
    Map<String, DoseEvent> latestEvents,
  ) {
    final date = DateTime.tryParse(day);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              date == null ? day : DateFormat('EEEE, d MMM yyyy').format(date),
              style: const pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              '${occurrences.length} scheduled '
              '${occurrences.length == 1 ? 'dose' : 'doses'}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.SizedBox(height: 7),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(7),
          ),
          child: pw.Column(
            children: [
              for (var index = 0; index < occurrences.length; index++) ...[
                _doseRow(
                  occurrences[index],
                  medications[occurrences[index].medicationId],
                  latestEvents[occurrences[index].id],
                ),
                if (index < occurrences.length - 1)
                  pw.Divider(height: 1, color: PdfColors.grey300),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _doseRow(
    DoseOccurrence occurrence,
    Medication? medication,
    DoseEvent? event,
  ) {
    final name = medication?.name ?? 'Medication';
    final detail = medication == null
        ? DateFormat('h:mm a').format(occurrence.scheduledAt.toLocal())
        : '${medication.displayStrength} | ${medication.displayDose} | '
            '${DateFormat('h:mm a').format(occurrence.scheduledAt.toLocal())}';
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  name,
                  style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  detail,
                  style:
                      const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                _statusLabel(occurrence.status),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _statusColor(occurrence.status),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                _eventDetail(occurrence, event),
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _statusLabel(DoseStatus status) => switch (status) {
        DoseStatus.taken => 'Taken',
        DoseStatus.missed => 'Missed',
        DoseStatus.skipped => 'Skipped',
        DoseStatus.overdue => 'Overdue',
        DoseStatus.snoozed => 'Snoozed',
        DoseStatus.pending => 'Pending',
      };

  static PdfColor _statusColor(DoseStatus status) => switch (status) {
        DoseStatus.taken => PdfColor.fromHex('#14735C'),
        DoseStatus.skipped => PdfColor.fromHex('#B42345'),
        DoseStatus.overdue => PdfColor.fromHex('#9B1C1C'),
        DoseStatus.snoozed => PdfColor.fromHex('#92400E'),
        DoseStatus.missed => PdfColors.grey700,
        DoseStatus.pending => PdfColor.fromHex('#385E8A'),
      };

  static String _eventDetail(DoseOccurrence occurrence, DoseEvent? event) {
    if (occurrence.status == DoseStatus.taken && event != null) {
      return 'Recorded ${DateFormat('h:mm a').format(event.recordedAt.toLocal())}';
    }
    if (occurrence.status == DoseStatus.skipped) {
      final reason = event?.skipReason?.trim();
      return reason?.isNotEmpty == true ? reason! : 'Skipped dose';
    }
    if (occurrence.status == DoseStatus.snoozed) {
      final until = event?.snoozeUntil ?? occurrence.snoozeUntil;
      return until == null
          ? 'Snoozed'
          : 'Until ${DateFormat('h:mm a').format(until.toLocal())}';
    }
    return _statusLabel(occurrence.status);
  }
}
