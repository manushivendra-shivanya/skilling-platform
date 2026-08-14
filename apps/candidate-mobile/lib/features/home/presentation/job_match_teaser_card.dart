import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_accent_pill.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon_plate.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../jobs/presentation/jobs_controller.dart';

/// Teases the candidate's single best-fit open job below the Journey card.
///
/// Reuses Jobs' own `jobsControllerProvider` rather than recomputing
/// anything: `JobsState.visibleJobs()` is already match-sorted for the
/// default "For you" tab (see that class's own doc comment), so this widget
/// only has to read its first item. Sharing the provider also means tapping
/// through to Jobs shows already-loaded data, not a second fetch.
///
/// Cross-feature `ref.watch` from Home into Jobs follows existing precedent
/// in this codebase rather than crossing a real boundary: Jobs' own
/// controller already reaches into Career Passport and Shift for the same
/// match computation, and `careerPassportRepositoryProvider` composes
/// providers from four other features. Home not depending on anything
/// outside its own dashboard repository until now was circumstance, not an
/// architectural rule.
///
/// Loading and error states render nothing. This is below-the-fold
/// enrichment, not a primary flow -- a slow or failed Jobs load should never
/// put an error card on Home, since Jobs is still reachable directly from
/// the shell either way.
class JobMatchTeaserCard extends ConsumerWidget {
  const JobMatchTeaserCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsState = ref.watch(jobsControllerProvider);
    final l10n = AppLocalizations.of(context);

    return jobsState.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (state) {
        final items = state.visibleJobs();
        if (items.isEmpty) return const SizedBox.shrink();
        final top = items.first;
        final matchLabel = l10n.homeJobMatchTeaserPercent(top.matchScore);

        return AppCard(
          onTap: onTap,
          // Composed from already-localized pieces, the same way
          // JourneyTimelineCard and _ShortcutRow build theirs -- not a new
          // combinatorial ARB key.
          semanticLabel:
              '${l10n.homeJobMatchTeaserLabel}: ${top.job.title}, '
              '${top.job.employer}. $matchLabel.',
          child: Row(
            children: [
              const AppIconPlate(
                icon: Icons.work_outline,
                background: AppColors.brandSoft,
                foreground: AppColors.brand,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeJobMatchTeaserLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                    Text(
                      top.job.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      top.job.employer,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppAccentPill(
                icon: Icons.star_rounded,
                label: matchLabel,
                background: AppColors.brandSoft,
                foreground: AppColors.brand,
              ),
            ],
          ),
        );
      },
    );
  }
}
