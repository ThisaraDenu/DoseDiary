import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/dd_card.dart';
import '../../core/widgets/dd_empty_state.dart';
import 'settings_providers.dart';

export 'account_screen.dart' show AccountScreen;

class AccessibilityScreen extends ConsumerWidget {
  const AccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(title: const Text('Accessibility')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.screenMargin),
        children: [
          // Text size
          DdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Text Size', style: AppTextStyles.bodyBold()),
                const SizedBox(height: AppDimensions.stackSm),
                Text(
                  'Preview text — ${_scaleLabel(settings.textScaleFactor)}',
                  style: AppTextStyles.bodyLg().copyWith(
                    fontSize: 16 * settings.textScaleFactor,
                  ),
                ),
                const SizedBox(height: AppDimensions.stackMd),
                Slider(
                  value: settings.textScaleFactor,
                  min: 0.8,
                  max: 1.6,
                  divisions: 8,
                  activeColor: AppColors.primaryAction,
                  label: _scaleLabel(settings.textScaleFactor),
                  onChanged: (v) => notifier.setTextScale(v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Smaller', style: AppTextStyles.caption()),
                    Text('Larger', style: AppTextStyles.caption()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.stackLg),

          // Simple wording
          DdCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Simpler Language', style: AppTextStyles.bodyBold()),
                      const SizedBox(height: 4),
                      Text(
                        'Use shorter, plainer words throughout the app.',
                        style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: settings.simpleWording,
                  onChanged: (v) => notifier.setSimpleWording(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.stackLg),

          // Language
          DdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Language', style: AppTextStyles.bodyBold()),
                const SizedBox(height: AppDimensions.stackSm),
                for (final lang in [('en', 'English'), ('si', 'Sinhala (සිංහල)'), ('ta', 'Tamil (தமிழ்)')])
                  RadioListTile<String>(
                    title: Text(lang.$2, style: AppTextStyles.bodyXl()),
                    value: lang.$1,
                    groupValue: settings.locale.languageCode,
                    activeColor: AppColors.primaryAction,
                    onChanged: (v) => notifier.setLanguage(v!),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _scaleLabel(double scale) {
    if (scale <= 0.85) return 'Small';
    if (scale <= 0.95) return 'Normal–Small';
    if (scale <= 1.05) return 'Normal';
    if (scale <= 1.15) return 'Large';
    if (scale <= 1.35) return 'Extra Large';
    return 'Largest';
  }
}

// ── Notification Settings ─────────────────────────────────────────────────────

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.screenMargin),
        children: [
          DdCard(
            child: Column(
              children: [
                _SwitchRow(
                  label: 'Medication Reminders',
                  subtitle: 'Notify me when a dose is due',
                  value: settings.notificationRemindersEnabled,
                  onChanged: (v) => notifier.setNotificationReminders(v),
                ),
                const Divider(),
                _SwitchRow(
                  label: 'Sound',
                  subtitle: 'Play a sound with notifications',
                  value: settings.notificationSound,
                  onChanged: (v) => notifier.setNotificationSound(v),
                ),
                const Divider(),
                _SwitchRow(
                  label: 'Vibration',
                  subtitle: 'Vibrate with notifications',
                  value: settings.notificationVibration,
                  onChanged: (v) => notifier.setNotificationVibration(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.stackXl),

          Text('Retry & Grace Period', style: AppTextStyles.headlineMd()),
          const SizedBox(height: AppDimensions.stackSm),
          Text(
            'If you don\'t respond, DoseDiary will send up to ${settings.retryCount} follow-up reminders. Caregiver alerts go out after ${settings.gracePeriodMinutes} minutes.',
            style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.stackLg),

          DdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Follow-up reminders: ${settings.retryCount}', style: AppTextStyles.bodyBold()),
                Slider(
                  value: settings.retryCount.toDouble(),
                  min: 0,
                  max: 5,
                  divisions: 5,
                  activeColor: AppColors.primaryAction,
                  label: settings.retryCount.toString(),
                  onChanged: (v) => notifier.setRetryCount(v.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.stackLg),

          DdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Caregiver alert after: ${settings.gracePeriodMinutes} min', style: AppTextStyles.bodyBold()),
                Slider(
                  value: settings.gracePeriodMinutes.toDouble(),
                  min: 15,
                  max: 120,
                  divisions: 7,
                  activeColor: AppColors.primaryAction,
                  label: '${settings.gracePeriodMinutes} min',
                  onChanged: (v) => notifier.setGracePeriod(v.round()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        title: Text(label, style: AppTextStyles.bodyBold()),
        subtitle: subtitle != null ? Text(subtitle!, style: AppTextStyles.caption()) : null,
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryAction,
        contentPadding: EdgeInsets.zero,
      );
}

// ── Privacy ───────────────────────────────────────────────────────────────────

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      backgroundColor: AppColors.scaffoldBackground,
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.screenMargin),
        children: [
          DdCard(
            child: _SwitchRow(
              label: 'Safe Notification Previews',
              subtitle: 'Show only "Dose reminder" in lock-screen notifications instead of medicine names.',
              value: settings.privacySafePreviews,
              onChanged: (v) => notifier.setPrivacySafePreviews(v),
            ),
          ),
          const SizedBox(height: AppDimensions.stackLg),
          DdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Data Storage', style: AppTextStyles.bodyBold()),
                const SizedBox(height: AppDimensions.stackSm),
                Text(
                  'Your medication records are stored locally on this device and optionally synced to a secure cloud account when you sign in.',
                  style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ── Safety Info ────────────────────────────────────────────────────────────────

class SafetyInfoScreen extends StatelessWidget {
  const SafetyInfoScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Medical Safety Notice')),
        backgroundColor: AppColors.scaffoldBackground,
        body: ListView(
          padding: const EdgeInsets.all(AppDimensions.screenMargin),
          children: [
            DdCard(
              borderColor: AppColors.primaryAction.withOpacity(0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.health_and_safety_rounded, color: AppColors.primaryAction),
                      const SizedBox(width: 8),
                      Text('Important Notice', style: AppTextStyles.bodyBold(color: AppColors.primaryAction)),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.stackMd),
                  Text(
                    'DoseDiary is a personal medication reminder and adherence tracking tool.\n\n'
                    'This app does NOT:\n'
                    '• Diagnose medical conditions\n'
                    '• Recommend treatment changes\n'
                    '• Calculate recommended dosages\n'
                    '• Give medical instructions\n'
                    '• Replace professional medical advice\n\n'
                    'Always follow the instructions of your doctor, pharmacist, or other qualified healthcare provider.\n\n'
                    'If you have any concerns about your medication, contact your healthcare provider immediately.',
                    style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

// ── Help ───────────────────────────────────────────────────────────────────────

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Help & Support')),
        backgroundColor: AppColors.scaffoldBackground,
        body: ListView(
          padding: const EdgeInsets.all(AppDimensions.screenMargin),
          children: const [
            _FaqItem(
              question: 'How do I add a medication?',
              answer: 'Go to the Medications tab and tap the "+" button. Fill in the medicine name, strength, dose, and set reminder times.',
            ),
            _FaqItem(
              question: 'What happens if I miss a dose?',
              answer: 'DoseDiary marks the dose as missed in your history. Your caregiver (if set up) will receive an alert if you don\'t respond within the grace period.',
            ),
            _FaqItem(
              question: 'How do caregivers access my schedule?',
              answer: 'Go to Settings → Caregivers and invite someone by email. You choose exactly what they can see.',
            ),
            _FaqItem(
              question: 'Does the app tell me what dose to take?',
              answer: 'No. DoseDiary only reminds you of the schedule you set up yourself. It does not give medical advice or calculate doses.',
            ),
            _FaqItem(
              question: 'Is my data private?',
              answer: 'Your data is stored locally on this device. You can optionally sync to a secure cloud account. Medication names are never shared with caregivers.',
            ),
          ],
        ),
      );
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.stackMd),
        child: DdCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: AppDimensions.stackSm),
            title: Text(question, style: AppTextStyles.bodyBold()),
            children: [Text(answer, style: AppTextStyles.bodyLg(color: AppColors.textSecondary))],
          ),
        ),
      );
}

// ── Notification Centre ───────────────────────────────────────────────────────

class NotificationCentreScreen extends StatelessWidget {
  const NotificationCentreScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        backgroundColor: AppColors.scaffoldBackground,
        body: const DdEmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'No notifications',
          subtitle: 'Reminders and alerts will appear here.',
        ),
      );
}

