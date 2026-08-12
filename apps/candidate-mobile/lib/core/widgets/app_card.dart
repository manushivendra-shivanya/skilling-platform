import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_elevation.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.semanticLabel,
    this.backgroundColor,
    this.elevation = AppElevation.low,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;
  final Color? backgroundColor;

  /// Defaults to [AppElevation.low], the flat card look every other
  /// caller relies on. Pass [AppElevation.medium] (or higher) only when a
  /// card is deliberately meant to read as raised above its surroundings
  /// -- e.g. a toolbar wrapper sitting on top of ordinary page content.
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: backgroundColor ?? AppColors.surface,
      elevation: elevation,
      shadowColor: AppColors.ink.withValues(alpha: 0.12),
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.largeBorder,
        side: BorderSide(color: AppColors.surfaceMuted),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (semanticLabel == null) {
      return content;
    }

    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      child: ExcludeSemantics(child: content),
    );
  }
}
