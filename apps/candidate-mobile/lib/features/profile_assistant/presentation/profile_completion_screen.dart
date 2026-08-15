import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_meter_bar.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../profile_details/presentation/detailed_profile_controller.dart';
import '../domain/profile_gap.dart';
import 'profile_gap_labels.dart';

/// "Finish your profile" -- names exactly what's still missing and offers
/// two honest ways to fix it: talk to the assistant, or go fill the forms
/// in by hand.
///
/// The gap list is a pure local computation (`findProfileGaps`), so this
/// screen is fully useful even in a build with no AI backend configured;
/// only the assistant button leads somewhere that needs one.
class ProfileCompletionScreen extends ConsumerWidget {
  const ProfileCompletionScreen({
    required this.onOpenAssistant,
    required this.onFillManually,
    super.key,
  });

  final VoidCallback onOpenAssistant;
  final VoidCallback onFillManually;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(detailedProfileControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileCompletionScreenTitle)),
      body: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              AppSkeleton(height: 110),
              SizedBox(height: AppSpacing.md),
              AppSkeleton(height: 220),
            ],
          ),
        ),
        error: (error, stackTrace) => AppErrorState(
          title: l10n.homeLoadErrorTitle,
          message: error is AppFailure
              ? error.localizedMessage(l10n)
              : l10n.homeLoadErrorMessage,
          onAction: () =>
              ref.read(detailedProfileControllerProvider.notifier).retry(),
        ),
        data: (profile) {
          final gaps = findProfileGaps(profile);
          final percent = profileFieldCompletionPercent(profile);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppCard(
                backgroundColor: AppColors.brand,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.profileCompletionHeading(percent),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      gaps.isEmpty
                          ? l10n.profileCompletionAllDone
                          : l10n.profileCompletionSubheadingWithGaps(
                              gaps.length,
                            ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppMeterBar(value: percent / 100),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              if (gaps.isNotEmpty) ...[
                Text(
                  l10n.profileCompletionStillMissingLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                AppCard(
                  child: Column(
                    children: [
                      for (final gap in gaps)
                        _GapRow(
                          key: ValueKey('profile-gap-${gap.id.name}'),
                          gap: gap,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  key: const ValueKey('profile-completion-assistant-button'),
                  label: l10n.profileCompletionAssistantButton,
                  leadingIcon: Icons.auto_awesome_outlined,
                  onPressed: onOpenAssistant,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: l10n.profileCompletionManualButton,
                  variant: AppButtonVariant.secondary,
                  onPressed: onFillManually,
                ),
              ] else
                AppButton(
                  label: l10n.profileCompletionBackToProfileButton,
                  onPressed: onFillManually,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GapRow extends StatelessWidget {
  const _GapRow({required this.gap, super.key});

  final ProfileGap gap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isTopFilter = gap.priority == ProfileGapPriority.recruiterFilter;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            isTopFilter ? Icons.priority_high_rounded : Icons.circle_outlined,
            size: 18,
            color: isTopFilter ? AppColors.warning : AppColors.outline,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              profileGapLabel(gap.id, l10n),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (isTopFilter)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l10n.profileCompletionRecruiterFilterTag,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
