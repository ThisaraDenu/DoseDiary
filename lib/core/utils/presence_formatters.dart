import 'package:intl/intl.dart';

String formatLastActive(String value, {DateTime? now}) {
  final parsed = DateTime.tryParse(value.trim());
  if (parsed == null) return value;

  final reference = now ?? DateTime.now();
  final difference = reference.toUtc().difference(parsed.toUtc());

  if (difference.isNegative || difference.inMinutes < 2) {
    return 'Active now';
  }
  if (difference.inMinutes < 60) {
    return 'Active ${difference.inMinutes}m ago';
  }
  if (difference.inHours < 24) {
    return 'Active ${difference.inHours}h ago';
  }
  if (difference.inDays < 7) {
    return 'Active ${difference.inDays}d ago';
  }
  return 'Last active ${DateFormat('MMM d').format(parsed.toLocal())}';
}
