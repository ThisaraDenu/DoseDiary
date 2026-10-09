import 'package:dose_diary/core/services/phone_dialer_service.dart';
import 'package:dose_diary/core/utils/presence_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('live presence formatting', () {
    final now = DateTime.utc(2026, 10, 8, 10);

    test('shows a recent heartbeat as active now', () {
      expect(
        formatLastActive(
          DateTime.utc(2026, 10, 8, 9, 59).toIso8601String(),
          now: now,
        ),
        'Active now',
      );
    });

    test('shows elapsed minutes and hours from a cloud timestamp', () {
      expect(
        formatLastActive(
          DateTime.utc(2026, 10, 8, 9, 48).toIso8601String(),
          now: now,
        ),
        'Active 12m ago',
      );
      expect(
        formatLastActive(
          DateTime.utc(2026, 10, 8, 7).toIso8601String(),
          now: now,
        ),
        'Active 3h ago',
      );
    });

    test('preserves legacy display text', () {
      expect(formatLastActive('Active 12m ago', now: now), 'Active 12m ago');
    });
  });

  group('phone dialer normalization', () {
    test('preserves international dialing prefix and removes formatting', () {
      expect(PhoneDialerService.normalize('+94 77-123 4567'), '+94771234567');
    });

    test('rejects missing phone numbers', () {
      expect(PhoneDialerService.normalize(null), isNull);
      expect(PhoneDialerService.normalize('  '), isNull);
    });
  });
}
