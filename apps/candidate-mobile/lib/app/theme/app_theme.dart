import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_elevation.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

ThemeData buildAppTheme() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: Brightness.light,
        surface: AppColors.surface,
        error: AppColors.error,
      ).copyWith(
        primary: AppColors.brand,
        onPrimary: Colors.white,
        primaryContainer: AppColors.brandSoft,
        onPrimaryContainer: AppColors.brandDark,
        secondary: AppColors.accent,
        secondaryContainer: AppColors.accentSoft,
        surfaceContainerLow: AppColors.canvas,
        surfaceContainer: AppColors.surfaceMuted,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.inkMuted,
        outline: AppColors.outline,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.canvas,
    textTheme: AppTypography.textTheme(AppColors.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: colorScheme.onSurface,
      elevation: AppElevation.none,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: const OutlineInputBorder(borderRadius: AppRadius.mediumBorder),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.mediumBorder,
        borderSide: BorderSide(color: AppColors.outline),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.mediumBorder,
        borderSide: BorderSide(color: AppColors.brand, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.mediumBorder,
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.mediumBorder,
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.mediumBorder,
        ),
        textStyle: AppTypography.textTheme(AppColors.ink).labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.mediumBorder,
        ),
        side: const BorderSide(color: AppColors.brand),
        textStyle: AppTypography.textTheme(AppColors.ink).labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.mediumBorder,
        ),
        textStyle: AppTypography.textTheme(AppColors.ink).labelLarge,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      showCloseIcon: true,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      modalBackgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.extraLarge),
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.brand,
      linearTrackColor: AppColors.brandSoft,
    ),
  );
}
