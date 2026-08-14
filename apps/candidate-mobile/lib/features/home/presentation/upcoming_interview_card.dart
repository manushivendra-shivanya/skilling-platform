import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../l10n/generated/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';

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
                      l10n.homeInterviewLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.accent,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      l10n.homeInterviewTitle(interview.employerName),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${_formatWhen(interview.scheduledAt, isHindi)} · '
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
            label: l10n.homeInterviewPrepare,
            variant: AppButtonVariant.secondary,
            onPressed: onPrepare,
          ),
        ],
      ),
    );
  }
}

/// Weekday and time.
///
/// Was a single hardcoded romanised-Hindi list ("Somvar, Mangalvar, ...")
/// regardless of language -- the app's old permanent-Hinglish default. Now
/// that the language toggle is real, each locale gets its own real weekday
/// names rather than the app defaulting to Hinglish's romanisation for
/// English too. Still not `intl`'s `DateFormat` for the Hindi case: proper
/// Devanagari weekday names from locale data are correct, but this app has
/// no other `intl`-formatted dates to be consistent with, and a plain
/// lookup table needs no locale-data initialization to get right in tests.
String _formatWhen(DateTime when, bool isHindi) {
  const englishDays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const hindiDays = <String>[
    'सोमवार',
    'मंगलवार',
    'बुधवार',
    'गुरुवार',
    'शुक्रवार',
    'शनिवार',
    'रविवार',
  ];
  final days = isHindi ? hindiDays : englishDays;
  final day = days[(when.weekday - 1).clamp(0, 6)];
  final hour = when.hour.toString().padLeft(2, '0');
  final minute = when.minute.toString().padLeft(2, '0');
  return '$day, $hour:$minute';
}
