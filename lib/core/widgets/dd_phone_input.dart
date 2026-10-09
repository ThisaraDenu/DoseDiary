import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Represents a country/region with its international dialing code and flag emoji.
class CountryRegion {
  final String name;
  final String code;
  final String dialCode;
  final String flag;

  const CountryRegion({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
  });

  /// Default region: Sri Lanka (matching DoseDiary locales: en, si, ta)
  static const CountryRegion defaultRegion = CountryRegion(
    name: 'Sri Lanka',
    code: 'LK',
    dialCode: '+94',
    flag: '🇱🇰',
  );

  /// Checks if this country matches a search query (name, code, or dial code)
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final cleanDial = dialCode.replaceAll('+', '');
    final cleanQ = q.replaceAll('+', '');
    return name.toLowerCase().contains(q) ||
        code.toLowerCase().contains(q) ||
        dialCode.contains(q) ||
        cleanDial.contains(cleanQ);
  }

  /// Parses a full international phone string (e.g. "+94 771234567" or "+14155552671")
  /// into a matching [CountryRegion] and national number string.
  static ({CountryRegion region, String nationalNumber}) parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return (region: defaultRegion, nationalNumber: '');
    }

    final trimmed = raw.trim();
    // Sort all countries by dial code length descending so +971 is matched before +97 etc.
    final sorted = List<CountryRegion>.from(allCountries)
      ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));

    for (final country in sorted) {
      if (trimmed.startsWith(country.dialCode)) {
        final rest = trimmed.substring(country.dialCode.length).trim();
        return (region: country, nationalNumber: rest);
      }
    }

    return (region: defaultRegion, nationalNumber: trimmed);
  }

  /// Comprehensive list of countries & regions
  static const List<CountryRegion> allCountries = [
    // South Asia & Southeast Asia
    CountryRegion(name: 'Sri Lanka', code: 'LK', dialCode: '+94', flag: '🇱🇰'),
    CountryRegion(name: 'India', code: 'IN', dialCode: '+91', flag: '🇮🇳'),
    CountryRegion(name: 'Maldives', code: 'MV', dialCode: '+960', flag: '🇲🇻'),
    CountryRegion(name: 'Pakistan', code: 'PK', dialCode: '+92', flag: '🇵🇰'),
    CountryRegion(
        name: 'Bangladesh', code: 'BD', dialCode: '+880', flag: '🇧🇩'),
    CountryRegion(name: 'Nepal', code: 'NP', dialCode: '+977', flag: '🇳🇵'),
    CountryRegion(name: 'Singapore', code: 'SG', dialCode: '+65', flag: '🇸🇬'),
    CountryRegion(name: 'Malaysia', code: 'MY', dialCode: '+60', flag: '🇲🇾'),
    CountryRegion(
        name: 'Philippines', code: 'PH', dialCode: '+63', flag: '🇵🇭'),
    CountryRegion(name: 'Indonesia', code: 'ID', dialCode: '+62', flag: '🇮🇩'),
    CountryRegion(name: 'Thailand', code: 'TH', dialCode: '+66', flag: '🇹🇭'),
    CountryRegion(name: 'Vietnam', code: 'VN', dialCode: '+84', flag: '🇻🇳'),

    // Middle East
    CountryRegion(
        name: 'United Arab Emirates',
        code: 'AE',
        dialCode: '+971',
        flag: '🇦🇪'),
    CountryRegion(
        name: 'Saudi Arabia', code: 'SA', dialCode: '+966', flag: '🇸🇦'),
    CountryRegion(name: 'Qatar', code: 'QA', dialCode: '+974', flag: '🇶🇦'),
    CountryRegion(name: 'Kuwait', code: 'KW', dialCode: '+965', flag: '🇰🇼'),
    CountryRegion(name: 'Oman', code: 'OM', dialCode: '+968', flag: '🇴🇲'),
    CountryRegion(name: 'Bahrain', code: 'BH', dialCode: '+973', flag: '🇧🇭'),
    CountryRegion(name: 'Jordan', code: 'JO', dialCode: '+962', flag: '🇯🇴'),
    CountryRegion(name: 'Lebanon', code: 'LB', dialCode: '+961', flag: '🇱🇧'),
    CountryRegion(name: 'Israel', code: 'IL', dialCode: '+972', flag: '🇮🇱'),

    // Americas
    CountryRegion(
        name: 'United States', code: 'US', dialCode: '+1', flag: '🇺🇸'),
    CountryRegion(name: 'Canada', code: 'CA', dialCode: '+1', flag: '🇨🇦'),
    CountryRegion(name: 'Brazil', code: 'BR', dialCode: '+55', flag: '🇧🇷'),
    CountryRegion(name: 'Mexico', code: 'MX', dialCode: '+52', flag: '🇲🇽'),
    CountryRegion(name: 'Argentina', code: 'AR', dialCode: '+54', flag: '🇦🇷'),
    CountryRegion(name: 'Chile', code: 'CL', dialCode: '+56', flag: '🇨🇱'),
    CountryRegion(name: 'Colombia', code: 'CO', dialCode: '+57', flag: '🇨🇴'),
    CountryRegion(name: 'Peru', code: 'PE', dialCode: '+51', flag: '🇵🇪'),

    // Europe
    CountryRegion(
        name: 'United Kingdom', code: 'GB', dialCode: '+44', flag: '🇬🇧'),
    CountryRegion(name: 'Australia', code: 'AU', dialCode: '+61', flag: '🇦🇺'),
    CountryRegion(
        name: 'New Zealand', code: 'NZ', dialCode: '+64', flag: '🇳🇿'),
    CountryRegion(name: 'Germany', code: 'DE', dialCode: '+49', flag: '🇩🇪'),
    CountryRegion(name: 'France', code: 'FR', dialCode: '+33', flag: '🇫🇷'),
    CountryRegion(name: 'Italy', code: 'IT', dialCode: '+39', flag: '🇮🇹'),
    CountryRegion(name: 'Spain', code: 'ES', dialCode: '+34', flag: '🇪🇸'),
    CountryRegion(
        name: 'Netherlands', code: 'NL', dialCode: '+31', flag: '🇳🇱'),
    CountryRegion(
        name: 'Switzerland', code: 'CH', dialCode: '+41', flag: '🇨🇭'),
    CountryRegion(name: 'Sweden', code: 'SE', dialCode: '+46', flag: '🇸🇪'),
    CountryRegion(name: 'Norway', code: 'NO', dialCode: '+47', flag: '🇳🇴'),
    CountryRegion(name: 'Denmark', code: 'DK', dialCode: '+45', flag: '🇩🇰'),
    CountryRegion(name: 'Finland', code: 'FI', dialCode: '+358', flag: '🇫🇮'),
    CountryRegion(name: 'Ireland', code: 'IE', dialCode: '+353', flag: '🇮🇪'),
    CountryRegion(name: 'Portugal', code: 'PT', dialCode: '+351', flag: '🇵🇹'),
    CountryRegion(name: 'Austria', code: 'AT', dialCode: '+43', flag: '🇦🇹'),
    CountryRegion(name: 'Belgium', code: 'BE', dialCode: '+32', flag: '🇧🇪'),
    CountryRegion(name: 'Poland', code: 'PL', dialCode: '+48', flag: '🇵🇱'),
    CountryRegion(
        name: 'Czech Republic', code: 'CZ', dialCode: '+420', flag: '🇨🇿'),
    CountryRegion(name: 'Greece', code: 'GR', dialCode: '+30', flag: '🇬🇷'),
    CountryRegion(name: 'Turkey', code: 'TR', dialCode: '+90', flag: '🇹🇷'),
    CountryRegion(name: 'Ukraine', code: 'UA', dialCode: '+380', flag: '🇺🇦'),

    // East Asia
    CountryRegion(name: 'Japan', code: 'JP', dialCode: '+81', flag: '🇯🇵'),
    CountryRegion(
        name: 'South Korea', code: 'KR', dialCode: '+82', flag: '🇰🇷'),
    CountryRegion(name: 'China', code: 'CN', dialCode: '+86', flag: '🇨🇳'),
    CountryRegion(
        name: 'Hong Kong', code: 'HK', dialCode: '+852', flag: '🇭🇰'),
    CountryRegion(name: 'Taiwan', code: 'TW', dialCode: '+886', flag: '🇹🇼'),

    // Africa
    CountryRegion(
        name: 'South Africa', code: 'ZA', dialCode: '+27', flag: '🇿🇦'),
    CountryRegion(name: 'Egypt', code: 'EG', dialCode: '+20', flag: '🇪🇬'),
    CountryRegion(name: 'Nigeria', code: 'NG', dialCode: '+234', flag: '🇳🇬'),
    CountryRegion(name: 'Kenya', code: 'KE', dialCode: '+254', flag: '🇰🇪'),
  ];
}

/// Opens a bottom sheet to select a country/region with search capability.
Future<CountryRegion?> showCountryRegionPicker(
  BuildContext context, {
  CountryRegion? currentRegion,
}) {
  return showModalBottomSheet<CountryRegion>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CountryPickerSheet(currentRegion: currentRegion),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  final CountryRegion? currentRegion;
  const _CountryPickerSheet({this.currentRegion});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchController = TextEditingController();
  List<CountryRegion> _filteredCountries = CountryRegion.allCountries;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() {
      _filteredCountries = CountryRegion.allCountries
          .where((country) => country.matches(query))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  Icons.public_rounded,
                  color: AppColors.primaryAction,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Select Country / Region',
                  style: AppTextStyles.headlineMd().copyWith(fontSize: 18),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search country or dial code (e.g. +94)',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textTertiary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF6F7F9),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.primaryAction, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          // Country List
          Expanded(
            child: _filteredCountries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No country found',
                          style: AppTextStyles.bodyLg(
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredCountries.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 68,
                      endIndent: 20,
                      color: Color(0xFFF1F1F1),
                    ),
                    itemBuilder: (context, index) {
                      final item = _filteredCountries[index];
                      final isSelected =
                          widget.currentRegion?.code == item.code &&
                              widget.currentRegion?.dialCode == item.dialCode;

                      return InkWell(
                        onTap: () => Navigator.of(context).pop(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              Text(
                                item.flag,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.primaryAction
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                item.dialCode,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.primaryAction
                                      : AppColors.textSecondary,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: AppColors.primaryAction,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Modern phone number input with an integrated country/region selector.
class DdPhoneInput extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final CountryRegion selectedRegion;
  final ValueChanged<CountryRegion> onRegionChanged;
  final FormFieldValidator<String>? validator;
  final bool isRequired;
  final bool enabled;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  const DdPhoneInput({
    super.key,
    this.label = 'Phone Number',
    this.hint = '77 123 4567',
    required this.controller,
    required this.selectedRegion,
    required this.onRegionChanged,
    this.validator,
    this.isRequired = true,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
  });

  /// Formats the combined international phone number, e.g. "+94 771234567"
  static String formatFullNumber(CountryRegion region, String nationalNumber) {
    final clean = nationalNumber.replaceAll(RegExp(r'\s+'), '').trim();
    if (clean.isEmpty) return '';
    return '${region.dialCode} $clean';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.bodyBold()),
            if (isRequired)
              Text(
                'Required',
                style: AppTextStyles.caption(color: AppColors.primaryAction),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.stackSm),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9\s\-]')),
          ],
          style: AppTextStyles.bodyXl(),
          validator: validator ??
              (value) {
                if (!isRequired && (value == null || value.trim().isEmpty)) {
                  return null;
                }
                if (value == null || value.trim().isEmpty) {
                  return 'Phone number is required';
                }
                final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                if (digitsOnly.length < 6 || digitsOnly.length > 15) {
                  return 'Please enter a valid phone number (6-15 digits)';
                }
                return null;
              },
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: AppColors.primaryAction, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            // Region Selector Pill on the left
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 6, right: 8),
              child: InkWell(
                onTap: enabled
                    ? () async {
                        final picked = await showCountryRegionPicker(
                          context,
                          currentRegion: selectedRegion,
                        );
                        if (picked != null) {
                          onRegionChanged(picked);
                        }
                      }
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedRegion.flag,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        selectedRegion.dialCode,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            suffixIcon: const Icon(
              Icons.phone_outlined,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}
