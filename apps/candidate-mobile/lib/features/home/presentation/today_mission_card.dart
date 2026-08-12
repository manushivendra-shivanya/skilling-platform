import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_meter_bar.dart';
import '../domain/home_dashboard_repository.dart';

/// The one thing Home asks the candidate to do today.
///
/// This card owns the screen's only filled button. Everything below it is a
/// row or an outlined action, which is what makes the hierarchy readable at a
/// glance instead of presenting five equal choices.
class TodayMissionCard extends StatelessWidget {
  const TodayMissionCard({
    required this.mission,
    required this.onStart,
    super.key,
  });

  final TodayMission mission;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.extraLargeBorder,
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDark.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'आज का काम · AAJ KA KAAM',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.inkMuted,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            mission.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            mission.summary,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Cost and position are shown before the button, not after it: a
          // candidate on a prepaid plan decides whether to start based on
          // what the task will cost them in time and data.
          //
          // Wrap, not Row: at large text scale on a narrow screen the two
          // chips no longer fit on one line, and they must reflow rather
          // than overflow.
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _MetaChip(
                icon: Icons.schedule_outlined,
                label: '${mission.durationMinutes} min',
              ),
              _MetaChip(
                label: 'Step ${mission.stepNumber} of ${mission.totalSteps}',
                background: AppColors.accentSoft,
                foreground: AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppMeterBar(value: mission.progress),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'शुरू करें · Start',
            leadingIcon: Icons.play_arrow_rounded,
            onPressed: onStart,
            semanticLabel:
                'Start today\'s mission: ${mission.title}. '
                '${mission.durationMinutes} minutes.',
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    this.icon,
    this.background = AppColors.surfaceMuted,
    this.foreground = AppColors.inkMuted,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
