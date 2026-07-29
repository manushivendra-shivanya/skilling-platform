import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_icons.dart';

enum AppChipTone { neutral, info, success, warning, error }

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    required this.label,
    this.tone = AppChipTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final AppChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (backgroundColor, foregroundColor, fallbackIcon) = switch (tone) {
      AppChipTone.neutral => (
        AppColors.surfaceMuted,
        AppColors.ink,
        AppIcons.info,
      ),
      AppChipTone.info => (AppColors.infoSoft, AppColors.info, AppIcons.info),
      AppChipTone.success => (
        AppColors.successSoft,
        AppColors.success,
        AppIcons.success,
      ),
      AppChipTone.warning => (
        AppColors.warningSoft,
        AppColors.warning,
        AppIcons.warning,
      ),
      AppChipTone.error => (
        AppColors.errorSoft,
        AppColors.error,
        AppIcons.error,
      ),
    };

    return Semantics(
      label: '$label, ${tone.name}',
      child: ExcludeSemantics(
        child: Chip(
          avatar: Icon(icon ?? fallbackIcon, size: 18, color: foregroundColor),
          label: Text(label),
          backgroundColor: backgroundColor,
          side: BorderSide.none,
          labelStyle: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: foregroundColor),
        ),
      ),
    );
  }
}
