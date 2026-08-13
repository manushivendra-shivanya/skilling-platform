import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_gradient_hero.dart';
import '../../../core/widgets/app_readiness_ring.dart';
import '../domain/home_dashboard_repository.dart';

/// The branded block at the top of Home: who the candidate is, what they are
/// working towards, and how much proof they have so far.
///
/// Identity and status share one surface so the scrolling area below can be
/// reserved for actions.
///
/// [bottomInset] is empty gradient left below the content for a card that
/// straddles the header's bottom edge. Reserving the space here — rather than
/// nesting the card inside the header — keeps the card a sibling in the scroll
/// list, so it casts a real shadow onto both the gradient and the page.
///
/// [onOpenNotifications] lives here rather than on a shell AppBar: Home is
/// the one tab with no AppBar (see `MainNavigationShell`), so this is its
/// only route to notifications, styled to match the goal/language chips
/// already on this gradient.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.dashboard,
    required this.onOpenNotifications,
    this.bottomInset = 0,
    super.key,
  });

  final HomeDashboard dashboard;
  final VoidCallback onOpenNotifications;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    // Tinted white rather than a fixed grey: it keeps its relationship with
    // the gradient at every point down the header.
    final onBrandMuted = Colors.white.withValues(alpha: 0.72);

    // Home is the one tab with no AppBar (see `MainNavigationShell`), so
    // unlike every other tab's hero/header this one has nothing upstream
    // already consuming the top system-bar inset -- AppBar does that for
    // free via its own `primary: true` default. Without adding it back
    // here, the greeting and notification bell painted right under the
    // status bar, sometimes overlapping its icons/clock on edge-to-edge
    // Android builds (targetSdk 36 enforces edge-to-edge). The gradient
    // itself still bleeds all the way to y=0 for the intended full-bleed
    // look -- only the content padding grows, via MediaQuery rather than a
    // wrapping SafeArea, so the background keeps painting behind the bar.
    final topInset = MediaQuery.of(context).padding.top;

    return AppGradientHero(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topInset + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      stops: const [0.0, 0.55, 1.0],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'नमस्ते',
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: onBrandMuted),
                    ),
                    Text(
                      dashboard.candidateFirstName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _GoalChip(label: dashboard.goalRoleName),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _NotificationsButton(onPressed: onOpenNotifications),
              const SizedBox(width: AppSpacing.xs),
              const _LanguageChip(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              ReadinessRing(
                progress: dashboard.readinessProgress,
                trackColor: Colors.white.withValues(alpha: 0.22),
                progressColor: AppColors.highlight,
                child: Text(
                  '${(dashboard.readinessProgress * 100).round()}%',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TAIYARI · READINESS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: onBrandMuted,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      dashboard.readinessBand.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    // The window travels with the count: a bare number reads
                    // as lifetime, and recency is what employers weigh.
                    Row(
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          size: 14,
                          color: onBrandMuted,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Expanded(
                          child: Text(
                            '${dashboard.evidence.count} proof items · '
                            'last ${dashboard.evidence.windowDays} days',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: onBrandMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: AppRadius.mediumBorder,
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.adjust_outlined, size: 14, color: Colors.white),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Same translucent-white treatment as [_LanguageChip], sized as a tap
/// target rather than a chip: this is an action, not a status readout.
class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: IconButton(
        tooltip: 'Notifications',
        onPressed: onPressed,
        icon: const Icon(Icons.notifications_none_outlined),
        color: Colors.white,
        iconSize: 20,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Change language. Hindi or English.',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: AppRadius.smallBorder,
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Text(
          'हिं · EN',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
