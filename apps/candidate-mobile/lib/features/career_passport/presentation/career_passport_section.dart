import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../workplace_simulation/domain/simulation_runtime.dart';
import '../domain/career_passport.dart';
import 'career_passport_controller.dart';

const _disclaimer = 'Flora provides simulation evidence, not certification.';
const _sharingBoundaryCopy =
    'Turning this on does not send your Career Passport anywhere '
    'automatically -- it only marks your evidence as visible if an '
    'employer you apply to requests it. Flora does not have an employer '
    'portal yet, so employers cannot browse or search your Career '
    'Passport directly.';

class CareerPassportSection extends ConsumerWidget {
  const CareerPassportSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(careerPassportControllerProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Career Passport',
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
            error: (error, _) => _CareerPassportError(
              message: error is AppFailure
                  ? error.message
                  : 'Your Career Passport could not be loaded.',
              onRetry: () =>
                  ref.read(careerPassportControllerProvider.notifier).retry(),
            ),
            data: (value) => _CareerPassportBody(state: value),
          ),
        ],
      ),
    );
  }
}

class _CareerPassportError extends StatelessWidget {
  const _CareerPassportError({required this.message, required this.onRetry});

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

class _CareerPassportBody extends ConsumerWidget {
  const _CareerPassportBody({required this.state});

  final CareerPassportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          state.entries.isEmpty
              ? 'Complete a workplace simulation to start building your '
                    'Career Passport.'
              : '${state.entries.length} evidence '
                    '${state.entries.length == 1 ? 'record' : 'records'} '
                    'from your simulations.',
        ),
        if (state.entries.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'View Career Passport',
            variant: AppButtonVariant.secondary,
            onPressed: () => showAppBottomSheet<void>(
              context: context,
              title: 'Career Passport',
              child: _CareerPassportDetails(entries: state.entries),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: state.isShareable,
          onChanged: state.canManageSharing
              ? (value) => _toggleShareable(context, ref)
              : null,
          title: const Text('Shareable with employers'),
          subtitle: Text(
            state.canManageSharing
                ? 'Private by default. $_sharingBoundaryCopy'
                : 'Sharing requires an account connection.',
          ),
        ),
      ],
    );
  }

  Future<void> _toggleShareable(BuildContext context, WidgetRef ref) async {
    final failure = await ref
        .read(careerPassportControllerProvider.notifier)
        .toggleShareable();
    if (!context.mounted) return;
    showAppSnackBar(
      context: context,
      message: failure?.message ?? 'Sharing preference saved.',
      tone: failure == null ? AppMessageTone.success : AppMessageTone.error,
    );
  }
}

class _CareerPassportDetails extends StatelessWidget {
  const _CareerPassportDetails({required this.entries});

  final List<CareerPassportEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_disclaimer, style: Theme.of(context).textTheme.bodyMedium),
        const Text(
          'Every decision about who sees this evidence, and what it means, '
          'stays with you and the people you choose to share it with -- '
          'Flora does not rank or certify candidates.',
        ),
        const SizedBox(height: AppSpacing.md),
        for (final entry in entries) ...[
          _CareerPassportEntryTile(entry: entry),
          const Divider(),
        ],
        Text(
          _sharingBoundaryCopy,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        const AppBottomSheetCloseButton(),
      ],
    );
  }
}

class _CareerPassportEntryTile extends StatelessWidget {
  const _CareerPassportEntryTile({required this.entry});

  final CareerPassportEntry entry;

  @override
  Widget build(BuildContext context) {
    final evidence = entry.evidence;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            competencyDisplayName(evidence.competencyId),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(evidence.description),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            children: [
              AppStatusChip(
                label: EvidenceVerificationStatus.displayLabel(
                  evidence.verificationStatus,
                ),
                tone: _provenanceTone(evidence.verificationStatus),
              ),
              AppStatusChip(
                label: _freshnessLabel(entry.freshness),
                tone: _freshnessTone(entry.freshness),
              ),
              AppStatusChip(label: '${evidence.score}%'),
            ],
          ),
        ],
      ),
    );
  }

  AppChipTone _provenanceTone(String status) => switch (status) {
    EvidenceVerificationStatus.systemObserved => AppChipTone.info,
    EvidenceVerificationStatus.issuerVerified => AppChipTone.success,
    EvidenceVerificationStatus.partnerAttested => AppChipTone.info,
    EvidenceVerificationStatus.candidateReported => AppChipTone.neutral,
    _ => AppChipTone.warning,
  };

  String _freshnessLabel(EvidenceFreshnessState freshness) =>
      switch (freshness) {
        EvidenceFreshnessState.active => 'Active',
        EvidenceFreshnessState.superseded => 'Superseded',
        EvidenceFreshnessState.stale => 'Stale',
      };

  AppChipTone _freshnessTone(EvidenceFreshnessState freshness) =>
      switch (freshness) {
        EvidenceFreshnessState.active => AppChipTone.success,
        EvidenceFreshnessState.superseded => AppChipTone.neutral,
        EvidenceFreshnessState.stale => AppChipTone.warning,
      };
}
