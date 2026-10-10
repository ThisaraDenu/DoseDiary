import 'package:url_launcher/url_launcher.dart';

class PhoneDialerService {
  PhoneDialerService._();

  static String? normalize(String? phoneNumber) {
    final value = phoneNumber?.trim();
    if (value == null || value.isEmpty) return null;

    final normalized = value.replaceAll(RegExp(r'[^0-9+*#,;]'), '');
    return normalized.isEmpty ? null : normalized;
  }

  static Future<bool> open(String? phoneNumber) async {
    final normalized = normalize(phoneNumber);
    if (normalized == null) return false;

    try {
      return await launchUrl(
        Uri(scheme: 'tel', path: normalized),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
