import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';

/// One plain-language observation about a card's own numbers -- "8 lessons
/// left to finish Receiving" instead of a bare percentage and a bar left to
/// the reader to translate. Muted and quiet by design: it explains, it
/// doesn't compete with the card's own title or primary action.
///
/// Every instance renders a fact already computed from data the card is
/// already showing -- see the `*ProgressNote`/`stepsRemaining*` getters on
/// [HomeDashboard]/[TodayMission]/[PathwayProgress] that feed this. It never
/// carries data pulled in on its own.
class AppInsightLine extends StatelessWidget {
  const AppInsightLine({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.smallBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 5, right: AppSpacing.xs),
            decoration: const BoxDecoration(
              color: AppColors.brand,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
