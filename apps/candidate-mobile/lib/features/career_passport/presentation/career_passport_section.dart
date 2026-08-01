import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../workplace_simulation/domain/simulation_enums.dart';
import '../../workplace_simulation/domain/simulation_runtime.dart';
import '../domain/career_passport.dart';
import '../domain/career_passport_repository.dart';
import 'career_passport_controller.dart';

const _disclaimer = 'Flora provides simulation evidence, not certification.';

// What the toggle actually does, split by its current state so the
// wording is a statement of fact ("On." / "Off.") rather than a vague
// description of the feature in general.
const _sharingOnSubtitle =
    'On. Employers you\'ve applied to can review your Career Passport '
    'evidence for that application -- never employers you haven\'t applied '
    'to, and never for automatic ranking or certification. Turn this off '
    'any time to immediately stop new access.';
const _sharingOffSubtitle =
    'Off. Employers cannot see your Career Passport evidence, even for '
    'jobs you\'ve applied to.';

const _sharingBoundaryCopy =
    'Sharing only ever applies to employers whose job you applied to -- '
    'Flora has no employer portal for browsing or searching candidates. '
    'The employer reviews your evidence and decides; Flora does not rank, '
    'shortlist or certify you.';

const _shareLinkIntro =
    'Generate a link anyone can open to view your Career Passport '
    'evidence -- no Flora account needed. Revoke it any time to '
    'immediately stop access; a copy someone already downloaded cannot '
    'be recalled.';

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
          title: const Text('Shared with employers where you applied'),
          subtitle: Text(
            state.canManageSharing
                ? (state.isShareable ? _sharingOnSubtitle : _sharingOffSubtitle)
                : 'Sharing requires an account connection.',
          ),
        ),
        if (state.canManageShareLink) ...[
          const Divider(),
          const SizedBox(height: AppSpacing.xxs),
          Text('Share link', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(_shareLinkIntro),
          const SizedBox(height: AppSpacing.sm),
          _ShareLinkControl(shareLink: state.shareLink),
        ],
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

class _ShareLinkControl extends ConsumerWidget {
  const _ShareLinkControl({required this.shareLink});

  final ShareLink? shareLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = shareLink;
    if (link == null) {
      return AppButton(
        label: 'Generate share link',
        variant: AppButtonVariant.secondary,
        onPressed: () => _generate(context, ref),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(link.url, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Expires ${DateFormat.yMMMd().format(link.expiresAt.toLocal())}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Copy link',
                variant: AppButtonVariant.secondary,
                onPressed: () => _copy(context, link.url),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                label: 'Revoke',
                variant: AppButtonVariant.secondary,
                onPressed: () => _revoke(context, ref),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    final failure = await ref
        .read(careerPassportControllerProvider.notifier)
        .generateShareLink();
    if (!context.mounted) return;
    showAppSnackBar(
      context: context,
      message: failure?.message ?? 'Share link created.',
      tone: failure == null ? AppMessageTone.success : AppMessageTone.error,
    );
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final failure = await ref
        .read(careerPassportControllerProvider.notifier)
        .revokeShareLink();
    if (!context.mounted) return;
    showAppSnackBar(
      context: context,
      message: failure?.message ?? 'Share link revoked.',
      tone: failure == null ? AppMessageTone.success : AppMessageTone.error,
    );
  }

  Future<void> _copy(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    showAppSnackBar(
      context: context,
      message: 'Link copied.',
      tone: AppMessageTone.success,
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
          'Who can see this evidence is entirely your choice. When you do '
          'share it, the employer reviews it and decides -- Flora never '
          'ranks, shortlists or certifies you.',
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
    return InkWell(
      onTap: () => showAppBottomSheet<void>(
        context: context,
        title: competencyDisplayName(evidence.competencyId),
        child: _CareerPassportEntryDetails(entry: entry),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    competencyDisplayName(evidence.competencyId),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
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

/// Full detail for a single evidence record -- everything
/// [_CareerPassportEntryTile]'s summary chips don't have room for: which
/// simulation attempt produced it, the mission and scenario it was
/// generated against, and exactly when it was issued. Nothing here is
/// fetched separately; [EvidenceRecord] already carries every field shown.
class _CareerPassportEntryDetails extends StatelessWidget {
  const _CareerPassportEntryDetails({required this.entry});

  final CareerPassportEntry entry;

  @override
  Widget build(BuildContext context) {
    final evidence = entry.evidence;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(evidence.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(evidence.description),
        const SizedBox(height: AppSpacing.md),
        _DetailRow(label: 'Mission', value: evidence.missionId),
        _DetailRow(label: 'Mission version', value: evidence.missionVersion),
        _DetailRow(label: 'Scenario seed', value: '${evidence.scenarioSeed}'),
        _DetailRow(label: 'Attempt', value: evidence.attemptId),
        _DetailRow(
          label: 'Evidence type',
          value: _evidenceTypeLabel(evidence.evidenceType),
        ),
        _DetailRow(
          label: 'Issued',
          value: DateFormat.yMMMd().add_jm().format(
            evidence.issuedAt.toLocal(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppBottomSheetCloseButton(),
      ],
    );
  }

  String _evidenceTypeLabel(EvidenceType evidenceType) =>
      switch (evidenceType) {
        EvidenceType.simulationObservation => 'Simulation observation',
      };
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
