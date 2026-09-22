/// Dose status enum used throughout the app.
enum DoseStatus {
  pending,
  taken,
  missed,
  skipped,
  overdue,
  snoozed;

  static DoseStatus fromString(String value) => switch (value) {
        'taken' => DoseStatus.taken,
        'missed' => DoseStatus.missed,
        'skipped' => DoseStatus.skipped,
        'overdue' => DoseStatus.overdue,
        'snoozed' => DoseStatus.snoozed,
        _ => DoseStatus.pending,
      };

  String toDbString() => name;

  bool get isTerminal => this == taken || this == missed || this == skipped;
  bool get isActionable => this == pending || this == snoozed || this == overdue;
}
