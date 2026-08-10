import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../domain/home_dashboard_repository.dart';

/// A scheduled, real-world commitment.
///
/// This sits directly under the mission because it is the only thing on Home
/// the candidate cannot reschedule from inside the app. It uses the accent
/// tone rather than the brand green so it separates from the learning
/// surfaces below without competing with the primary button above.
class UpcomingInterviewCard extends StatelessWidget {
  const UpcomingInterviewCard({
    required this.interview,
    required this.onPrepare,
    super.key,
  });

  final UpcomingInterview interview;
  final VoidCallback onPrepare;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: AppRadius.extraLargeBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.mediumBorder,
                ),
                child: const Icon(
                  Icons.event_outlined,
                  size: 20,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AANE WALA · UPCOMING',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.accent,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Interview · ${interview.employerName}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${_formatWhen(interview.scheduledAt)} · '
                      '${interview.location}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.warning),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Taiyari karein · Prepare',
            variant: AppButtonVariant.secondary,
            onPressed: onPrepare,
          ),
        ],
      ),
    );
  }
}

/// Weekday and time, in the Hinglish register the rest of Home uses.
///
/// Deliberately not `intl`'s locale formatting: the day names are the ones a
/// supervisor says on a shift floor, and mixing a localised date into
/// romanised Hindi copy reads as machine-translated.
String _formatWhen(DateTime when) {
  const days = <String>[
    'Somvar',
    'Mangalvar',
    'Budhvar',
    'Guruvar',
    'Shukravar',
    'Shanivar',
    'Ravivar',
  ];
  final day = days[(when.weekday - 1).clamp(0, 6)];
  final hour = when.hour.toString().padLeft(2, '0');
  final minute = when.minute.toString().padLeft(2, '0');
  return '$day, $hour:$minute';
}
