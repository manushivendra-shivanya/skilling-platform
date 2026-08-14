import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_icon_plate.dart';
import '../../../core/widgets/app_meter_bar.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/role_readiness.dart';
import 'career_passport_controller.dart';

const _disclaimer =
    'Flora provides evidence and readiness signals, not certification.';

/// A summary card above [CareerPassportSection] on the "Me" tab: one row
/// per [ReadinessCategory], reduced from the same already-loaded
/// [CareerPassportState.entries] via [deriveRoleReadiness] -- no separate
/// fetch, same provider Career Passport itself reads.
class RoleReadinessSection extends ConsumerWidget {
  const RoleReadinessSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(careerPassportControllerProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Role Readiness', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _disclaimer,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
          const Divider(),
          state.when(
            loading: () => const AppSkeleton(height: 96),
            error: (error, _) => _RoleReadinessError(
              message: error is AppFailure
                  ? error.localizedMessage(AppLocalizations.of(context))
                  : 'Role readiness could not be loaded.',
              onRetry: () =>
                  ref.read(careerPassportControllerProvider.notifier).retry(),
            ),
            data: (value) => _RoleReadinessBody(readiness: value.readiness),
          ),
        ],
      ),
    );
  }
}

class _RoleReadinessError extends StatelessWidget {
  const _RoleReadinessError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Retry',
          variant: AppButtonVariant.secondary,
          expand: false,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _RoleReadinessBody extends StatelessWidget {
  const _RoleReadinessBody({required this.readiness});

  final List<RoleReadinessSummary> readiness;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final summary in readiness) ...[
          _RoleReadinessRow(summary: summary),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _RoleReadinessRow extends StatelessWidget {
  const _RoleReadinessRow({required this.summary});

  final RoleReadinessSummary summary;

  @override
  Widget build(BuildContext context) {
    final tone = switch (summary.level) {
      ReadinessLevel.ready => AppChipTone.success,
      ReadinessLevel.developing => AppChipTone.info,
      ReadinessLevel.needsPractice => AppChipTone.warning,
      ReadinessLevel.unknown => AppChipTone.neutral,
    };
    final (plateBackground, plateForeground) = _toneColors(tone);
    final label = readinessCategoryLabel(summary.category);
    final averageScore = summary.averageScore;
    return Semantics(
      label:
          '$label: ${readinessLevelLabel(summary.level)}'
          '${averageScore != null ? ', $averageScore% average' : ''}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconPlate(
              icon: _categoryIcon(summary.category),
              background: plateBackground,
              foreground: plateForeground,
              size: 36,
              iconSize: 18,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodyLarge),
                  // Honestly distinguishes "no evidence yet" (no bar) from
                  // a real low score (a bar showing it) -- matching how the
                  // rest of the app treats those as different states, not
                  // the same "0%".
                  if (averageScore != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    AppMeterBar(
                      value: averageScore / 100,
                      height: 4,
                      fillColor: plateForeground,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppStatusChip(
                  label: readinessLevelLabel(summary.level),
                  tone: tone,
                ),
                if (summary.evidenceCount > 0) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '(${summary.evidenceCount} record'
                    '${summary.evidenceCount == 1 ? '' : 's'})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

IconData _categoryIcon(ReadinessCategory category) => switch (category) {
  ReadinessCategory.receiving => Icons.move_to_inbox_outlined,
  ReadinessCategory.processing => Icons.build_outlined,
  ReadinessCategory.dispatch => Icons.local_shipping_outlined,
  ReadinessCategory.supervisor => Icons.supervisor_account_outlined,
};

/// The same soft-background/tone-foreground pairing [AppStatusChip] already
/// uses internally, reused here for the category icon plate and the score
/// meter bar's fill color rather than inventing a new color scale.
(Color, Color) _toneColors(AppChipTone tone) => switch (tone) {
  AppChipTone.neutral => (AppColors.surfaceMuted, AppColors.ink),
  AppChipTone.info => (AppColors.infoSoft, AppColors.info),
  AppChipTone.success => (AppColors.successSoft, AppColors.success),
  AppChipTone.warning => (AppColors.warningSoft, AppColors.warning),
  AppChipTone.error => (AppColors.errorSoft, AppColors.error),
};
