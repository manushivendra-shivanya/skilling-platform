import 'package:candidate_mobile/app/theme/app_colors.dart';
import 'package:candidate_mobile/app/theme/app_radius.dart';
import 'package:candidate_mobile/app/theme/app_spacing.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme uses the approved brand and accessible layout tokens', () {
    final theme = buildAppTheme();

    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, AppColors.brand);
    expect(theme.scaffoldBackgroundColor, AppColors.canvas);
    expect(theme.textTheme.bodyLarge?.fontSize, 16);
    expect(AppSpacing.md, 16);
    expect(AppRadius.medium, 12);
  });

  test('brand colour has strong contrast against white button text', () {
    final contrast = ThemeData.estimateBrightnessForColor(AppColors.brand);

    expect(contrast, Brightness.dark);
  });
}
