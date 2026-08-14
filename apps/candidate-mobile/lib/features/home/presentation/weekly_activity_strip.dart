import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/home_dashboard_repository.dart';

/// A small "pulse" of the candidate's last 7 days, sitting below the Journey
/// card: proof collected and applications sent this week.
///
/// Both figures reuse the exact tables/indexes [HomeDashboard.evidence] and
/// [HomeDashboard.applicationsSentThisMonth] already cite, just windowed to
/// 7 days instead of 30/the calendar month -- see
/// [HomeDashboard.evidenceThisWeek] and [HomeDashboard.applicationsThisWeek]
/// for the exact citation. Like every other Home field, both are mock-only
/// today.
///
/// No `onTap`: this is a status readout, not a destination -- there is
/// nowhere on Home that owns "this week" as its own screen to route to.
class WeeklyActivityStrip extends StatelessWidget {
  const WeeklyActivityStrip({required this.dashboard, super.key});

  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeWeeklySectionTitle,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.inkMuted,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            children: [
              AppStatusChip(
                icon: Icons.verified_outlined,
                tone: dashboard.evidenceThisWeek > 0
                    ? AppChipTone.success
                    : AppChipTone.neutral,
                label: l10n.homeWeeklyEvidenceChip(dashboard.evidenceThisWeek),
              ),
              AppStatusChip(
                icon: Icons.send_outlined,
                tone: dashboard.applicationsThisWeek > 0
                    ? AppChipTone.info
                    : AppChipTone.neutral,
                label: l10n.homeWeeklyApplicationsChip(
                  dashboard.applicationsThisWeek,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
