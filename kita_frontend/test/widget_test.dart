import 'package:flutter_test/flutter_test.dart';
import 'package:kita_frontend/core/theme/app_colors.dart';

void main() {
  test('AppColors smoke test', () {
    expect(AppColors.primaryGreen, isNotNull);
    expect(AppColors.darkBg, isNotNull);
    expect(AppColors.lightBg, isNotNull);
  });
}
