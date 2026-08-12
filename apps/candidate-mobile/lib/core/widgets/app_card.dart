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
    this.boxShadow,
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
  /// Ignored when [boxShadow] is set (see below).
  final double elevation;

  /// A hand-tuned shadow (e.g. `AppShadows.hero`) for a card that needs to
  /// read as genuinely elevated above the page, not just "raised a little"
  /// -- [Material.elevation]'s built-in shadow was tuned for ordinary card
  /// depth and can't produce that heavier, more deliberate look no matter
  /// how high the value goes. When set, this *replaces* the elevation
  /// shadow rather than layering on top of it (the card's own `elevation`
  /// is forced to 0), since stacking Material's shadow underneath a second,
  /// differently-tinted one produces a visible double shadow rather than
  /// one clean edge.
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final material = Material(
      color: backgroundColor ?? AppColors.surface,
      elevation: boxShadow == null ? elevation : 0,
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

    final content = boxShadow == null
        ? material
        : Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.largeBorder,
              boxShadow: boxShadow,
            ),
            child: material,
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
