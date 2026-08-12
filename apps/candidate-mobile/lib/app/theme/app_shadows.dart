import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Named, pre-tuned drop shadows for the handful of surfaces that need to
/// read as raised above ordinary page content. `AppCard`'s own
/// `Material.elevation` covers the default flat-card look (see
/// `AppCard.elevation`'s doc comment); these three tiers are for the
/// surfaces that want a real, hand-tuned [BoxShadow] instead of a bigger
/// elevation number -- consolidated from the near-identical shadows Home's
/// `TodayMissionCard`, Shift's hero `_ShiftCard`, and Shift's
/// `_AcceptShiftFooter` each separately hand-tuned (`AppColors.ink` or
/// `AppColors.brandDark` at low alpha, blur 16-28, a small offset) down to
/// 3 representative values rather than N near-duplicates.
///
/// `static final`, not `const`: [Color.withValues] isn't a const
/// constructor, so these are computed once at first use instead of at
/// compile time -- functionally identical for values that never change.
abstract final class AppShadows {
  /// Subtle default for a card that wants a touch more depth than
  /// `AppCard`'s flat `AppElevation.low` Material shadow without reading as
  /// a hero.
  static final List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.10),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// Heavier shadow for a card meant to read as the single most important
  /// thing on the screen -- matches Shift's `_ShiftCard.isHero` value
  /// exactly.
  static final List<BoxShadow> hero = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.18),
      blurRadius: 28,
      offset: const Offset(0, 14),
    ),
  ];

  /// Upward-facing shadow (negative y-offset) for chrome pinned to the
  /// bottom of the screen, so it reads as sitting above the content behind
  /// it rather than below it -- matches Shift's `_AcceptShiftFooter` value
  /// exactly.
  static final List<BoxShadow> stickyFooter = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.12),
      blurRadius: 16,
      offset: const Offset(0, -4),
    ),
  ];
}
