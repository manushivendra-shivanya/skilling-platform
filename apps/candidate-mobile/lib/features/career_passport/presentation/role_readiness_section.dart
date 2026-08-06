import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_skeleton.dart';
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
                  ? error.message
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
    final label = readinessCategoryLabel(summary.category);
    return Semantics(
      label:
          '$label: ${readinessLevelLabel(summary.level)}'
          '${summary.averageScore != null ? ', ${summary.averageScore}% average' : ''}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ),
            AppStatusChip(
              label: readinessLevelLabel(summary.level),
              tone: tone,
            ),
          ],
        ),
      ),
    );
  }
}
