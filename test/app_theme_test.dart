import 'package:dose_diary/core/theme/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selected accessible colour is applied to the shared app palette', () {
    AppColors.applyThemeColor(AppThemeColor.teal);

    expect(AppColors.primaryAction, AppThemeColor.teal.color);
    expect(AppColors.navBarActive, AppThemeColor.teal.color);
    expect(AppColors.primaryActionDark, AppThemeColor.teal.darkColor);
  });

  test('unknown persisted colour safely falls back to crimson', () {
    expect(AppThemeColor.fromName('not-a-theme'), AppThemeColor.crimson);
    expect(AppThemeColor.fromName(null), AppThemeColor.crimson);
  });
}
