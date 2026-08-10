import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../domain/home_dashboard_repository.dart';
import 'readiness_ring.dart';

/// The branded block at the top of Home: who the candidate is, what they are
/// working towards, and how much proof they have so far.
///
/// Identity and status share one surface so the scrolling area below can be
/// reserved for actions. [footer] renders inside the gradient, which is what
/// makes the mission card read as lifted off the header without a negative
/// margin or a transform.
class HomeHeader extends StatelessWidget {
  const HomeHeader({required this.dashboard, this.footer, super.key});

  final HomeDashboard dashboard;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    // Tinted white rather than a fixed grey: it keeps its relationship with
    // the gradient at every point down the header.
    final onBrandMuted = Colors.white.withValues(alpha: 0.72);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A7355), AppColors.brand, AppColors.brandDark],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
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
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.lg),
            footer!,
          ],
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
