import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shadows.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_icon_plate.dart';
import '../../../core/widgets/app_initials_avatar.dart';
import '../../../core/widgets/app_meter_bar.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../workplace_simulation/domain/simulation_enums.dart';
import '../../workplace_simulation/domain/simulation_runtime.dart';
import '../domain/career_passport.dart';
import '../domain/career_passport_repository.dart';
import 'career_passport_controller.dart';

// Was "simulation evidence" -- broadened now that micro-lesson
// assessments are a second evidence source alongside workplace
// simulations.
const _disclaimer = 'Flora provides evidence, not certification.';

const _sharingBoundaryCopy =
    'Sharing only ever applies to employers whose job you applied to -- '
    'Flora has no employer portal for browsing or searching candidates. '
    'The employer reviews your evidence and decides; Flora does not rank, '
    'shortlist or certify you.';

const _employerAccessIntro =
    'Decide employer by employer who can review your Career Passport '
    'evidence -- only employers whose job you applied to appear here, and '
    'none of them can see anything until you turn their access on. Turn it '
    'off any time to immediately stop new access.';

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
      // A touch more depth than the flat AppElevation.low every other card
      // defaults to -- this cluster (Career Passport, Role Readiness,
      // Persona, Networking) reads flat against the rest of the app, whose
      // hero treatment stops at Profile's own header. AppShadows.card is
      // the "subtle default" tier built for exactly this: more depth than
      // flat, without reading as a hero.
      boxShadow: AppShadows.card,
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
        if (state.canManageEmployerAccess) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Employer access',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(_employerAccessIntro),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Manage employer access',
            variant: AppButtonVariant.secondary,
            onPressed: () => showAppBottomSheet<void>(
              context: context,
              title: 'Employer access',
              child: const _EmployerAccessDetails(),
            ),
          ),
        ],
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
}

class _EmployerAccessDetails extends ConsumerWidget {
  const _EmployerAccessDetails();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched directly (rather than taking entries as a constructor
    // parameter) because this widget lives in a bottom-sheet route, not
    // inline in CareerPassportSection's own build -- a parameter would be
    // a frozen snapshot from when the sheet opened and wouldn't reflect a
    // toggle made while it's still on screen.
    final entries =
        ref
            .watch(careerPassportControllerProvider)
            .valueOrNull
            ?.employerAccess ??
        const <EmployerAccessEntry>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_employerAccessIntro),
        const SizedBox(height: AppSpacing.md),
        if (entries.isEmpty)
          const Text(
            'You have not applied to any jobs yet -- employers appear here '
            'once you apply.',
          )
        else
          for (final entry in entries)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: entry.granted,
              onChanged: (_) => _toggle(context, ref, entry),
              secondary: AppInitialsAvatar(
                name: entry.employerName,
                circular: false,
                size: 32,
              ),
              title: Text(entry.employerName),
              subtitle: Text(
                entry.granted ? 'Can review your evidence.' : 'No access.',
              ),
            ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _sharingBoundaryCopy,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        const AppBottomSheetCloseButton(),
      ],
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    EmployerAccessEntry entry,
  ) async {
    final failure = await ref
        .read(careerPassportControllerProvider.notifier)
        .toggleEmployerAccess(entry);
    if (!context.mounted) return;
    showAppSnackBar(
      context: context,
      message: failure?.message ?? 'Employer access updated.',
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

/// The same tone -> foreground color pairing [AppStatusChip] already uses
/// internally, exposed here so the score meter bar can be tinted to match
/// its paired chip instead of inventing a new color scale.
Color _toneColor(AppChipTone tone) => switch (tone) {
  AppChipTone.neutral => AppColors.ink,
  AppChipTone.info => AppColors.info,
  AppChipTone.success => AppColors.success,
  AppChipTone.warning => AppColors.warning,
  AppChipTone.error => AppColors.error,
};

class _CareerPassportEntryTile extends StatelessWidget {
  const _CareerPassportEntryTile({required this.entry});

  final CareerPassportEntry entry;

  @override
  Widget build(BuildContext context) {
    final evidence = entry.evidence;
    // Every evidence type shares the same "evidence entry" icon --
    // competencyId/evidenceType carry no per-competency icon mapping to
    // draw from, and inventing one would be guessing, not reusing data.
    const entryIcon = Icons.verified_outlined;
    final scoreTone = _provenanceTone(evidence.verificationStatus);
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppIconPlate(
                  icon: entryIcon,
                  background: AppColors.brandSoft,
                  foreground: AppColors.brand,
                  size: 36,
                  iconSize: 18,
                ),
                const SizedBox(width: AppSpacing.sm),
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
                  tone: scoreTone,
                ),
                AppStatusChip(
                  label: _freshnessLabel(entry.freshness),
                  tone: _freshnessTone(entry.freshness),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // A real scorecard for evidence.score -- the chip alone was the
            // only visual read of the number; the meter bar underneath
            // gives it a second, at-a-glance one, colored by the same
            // provenance tone the chips above already compute (not a new
            // threshold).
            Row(
              children: [
                AppStatusChip(label: '${evidence.score}%', tone: scoreTone),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppMeterBar(
                    value: evidence.score / 100,
                    fillColor: _toneColor(scoreTone),
                  ),
                ),
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
        // Micro-lesson evidence repurposes missionId as the source clip id
        // and has no real scenario -- labelling and showing only what
        // actually applies to each evidence type reads more honestly than
        // showing "Scenario seed: 0" for a clip that never had one.
        switch (evidence.evidenceType) {
          EvidenceType.simulationObservation => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailRow(label: 'Mission', value: evidence.missionId),
              _DetailRow(
                label: 'Mission version',
                value: evidence.missionVersion,
              ),
              _DetailRow(
                label: 'Scenario seed',
                value: '${evidence.scenarioSeed}',
              ),
            ],
          ),
          EvidenceType.microLessonAssessment => _DetailRow(
            label: 'Clip',
            value: evidence.missionId,
          ),
          EvidenceType.certificationExam => _DetailRow(
            label: 'Exam',
            value: evidence.missionId,
          ),
          EvidenceType.shiftCompletion => _DetailRow(
            label: 'Shift',
            value: evidence.missionId,
          ),
        },
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
        EvidenceType.microLessonAssessment => 'Micro-lesson assessment',
        EvidenceType.certificationExam => 'Certification exam',
        EvidenceType.shiftCompletion => 'Shift completion',
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
