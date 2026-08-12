import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_shadows.dart';
import '../../app/theme/app_spacing.dart';

/// Chrome-only wrapper for a bar pinned to the bottom of a screen: the
/// surface color, top border, upward shadow, and safe-area + padding every
/// sticky footer needs, without knowing anything about what's inside it.
/// Shift's `_AcceptShiftFooter` used to hand-roll this chrome itself
/// wrapped around its own eligibility-gated `AppButton` -- that gating
/// logic and the button stay exactly where they are, in Shift's own
/// widget; only the outer decoration moves here, so a future sticky footer
/// (e.g. a Career Passport CTA) gets the same chrome for free instead of
/// re-deriving these shadow/border values again.
class AppStickyFooter extends StatelessWidget {
  const AppStickyFooter({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.sm,
      AppSpacing.xl,
      AppSpacing.sm,
    ),
    super.key,
  });

  /// Typically the caller's own [AppButton], or a row of a few.
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.surfaceMuted)),
        boxShadow: AppShadows.stickyFooter,
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
