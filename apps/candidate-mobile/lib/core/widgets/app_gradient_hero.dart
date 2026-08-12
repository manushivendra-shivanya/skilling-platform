import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// A full-bleed container with the brand-to-brand-dark diagonal gradient
/// used by every screen that opens on a branded hero block (Home's
/// `HomeHeader`, Profile's `_IdentityHeader`) -- each of which used to
/// hand-roll its own near-identical `Container` + `LinearGradient`. This
/// widget owns only the gradient background, edge-to-edge sizing, and
/// padding; each screen's own content (greeting + readiness ring here,
/// avatar + name there) stays exactly as it was, passed in as [child].
///
/// Deliberately a plain [Widget] child rather than this widget owning any
/// layout opinion about what goes inside it -- the two donor screens have
/// completely different content shapes, and forcing a shared internal
/// layout would be the same duplication problem, just moved one level up.
class AppGradientHero extends StatelessWidget {
  const AppGradientHero({
    required this.child,
    this.gradientColors = const [
      AppColors.brandLight,
      AppColors.brand,
      AppColors.brandDark,
    ],
    this.stops,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    super.key,
  });

  final Widget child;
  final List<Color> gradientColors;

  /// Null means evenly spaced across [gradientColors], matching
  /// [LinearGradient]'s own default. Home's header passes an explicit
  /// uneven set so the lighter top color is confined to a small corner
  /// rather than a third of the gradient.
  final List<double>? stops;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
          stops: stops,
        ),
      ),
      child: child,
    );
  }
}
