import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';

/// A colored rounded-square container holding a centered icon -- the
/// "colored plate" every screen that needed one independently hand-rolled
/// (Home's `_IconPlate`, Shift's `_ShortcutPlate`) at slightly different
/// sizes. [size] stays caller-configurable rather than fixed: the two donor
/// call sites genuinely disagree (40 on Home's list rows, 36 on Shift's
/// shortcut strip) and neither is more "correct" than the other. [iconSize]
/// defaults to 20 to match both -- override only if a future call site
/// genuinely needs a different icon-to-plate ratio.
class AppIconPlate extends StatelessWidget {
  const AppIconPlate({
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 40,
    this.iconSize = 20,
    super.key,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  /// Outer edge of the square plate.
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.mediumBorder,
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}

/// [AppIconPlate] plus a text label underneath, wrapped in its own tap
/// target -- what Shift's `_ShortcutPlate` used to hand-roll for its
/// Availability / My shifts / Payouts / Support strip. Kept as a separate
/// widget rather than optional `onTap`/`label` params bolted onto
/// [AppIconPlate] itself: a bare plate (e.g. Home's list-row icon, where the
/// row -- not the plate -- is what's tappable) and a standalone
/// tappable-plate-with-label are different enough contracts that folding
/// them into one constructor would make every bare-plate call site reason
/// about unused label/onTap params too.
class AppIconPlateButton extends StatelessWidget {
  const AppIconPlateButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.size = 36,
    this.width = 68,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  /// Forwarded to the inner [AppIconPlate].
  final double size;

  /// Width of the whole tap target (plate + label), so labels wrap onto a
  /// second line rather than pushing neighbouring plates apart in a
  /// horizontally scrolling strip.
  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mediumBorder,
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIconPlate(
                  icon: icon,
                  background: background,
                  foreground: foreground,
                  size: size,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
