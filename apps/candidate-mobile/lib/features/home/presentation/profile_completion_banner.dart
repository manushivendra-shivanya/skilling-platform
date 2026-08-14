import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon_plate.dart';
import '../../../core/widgets/app_meter_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../profile_details/presentation/detailed_profile_controller.dart';

/// Nudges the candidate to finish their profile, until it's finished.
///
/// Watches `detailedProfileControllerProvider` independently of
/// `HomeDashboard` -- the same cross-feature pattern `JobMatchTeaserCard`
/// already uses, for the same reason: this is real, backend-persisted data
/// (see `DetailedCandidateProfile`), not something `MockHomeDashboardRepository`
/// should grow a mock field for.
///
/// Renders nothing once [DetailedCandidateProfile.isComplete] is true --
/// this banner's only job is to close itself out. Loading and error states
/// also render nothing, the same "below-the-fold enrichment, never an
/// error card on Home" rule `JobMatchTeaserCard` follows: a slow or failed
/// profile load shouldn't put an error banner on Home when the candidate
/// can still reach their profile directly from the shell.
class ProfileCompletionBanner extends ConsumerWidget {
  const ProfileCompletionBanner({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(detailedProfileControllerProvider);
    final l10n = AppLocalizations.of(context);

    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (profile) {
        if (profile.isComplete) return const SizedBox.shrink();
        final percent = profile.completionPercent;
        final percentLabel = l10n.profileDetailsCompletionLabel(percent);

        return AppCard(
          onTap: onTap,
          backgroundColor: AppColors.brandSoft,
          semanticLabel: '${l10n.homeProfileCompletionTitle}. $percentLabel.',
          child: Row(
            children: [
              const AppIconPlate(
                icon: Icons.badge_outlined,
                background: AppColors.surface,
                foreground: AppColors.brand,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeProfileCompletionTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        Expanded(child: AppMeterBar(value: percent / 100)),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          percentLabel,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.inkMuted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.brand,
              ),
            ],
          ),
        );
      },
    );
  }
}
