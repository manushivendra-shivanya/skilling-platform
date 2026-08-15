import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/resume_parsing_repository.dart';

/// Renders a structured [ResumeParseResult] for the candidate's own review
/// -- shared between the post-signup `ResumeImportScreen` (the primary
/// entry point) and onboarding step 6's `_ResumeUploadStep` (a lighter
/// secondary utility for anyone who reaches the wizard without having used
/// that screen), so the two don't carry two independently-drifting copies
/// of the same rendering logic.
///
/// Read-only, and deliberately not a place where a "not yet saved" claim
/// can go stale: this only ever appears *before* the candidate has
/// confirmed applying an extraction, at both call sites -- the footer's
/// "not yet saved" wording is accurate in both.
///
/// [footerAppliesImmediately] covers a real difference between those two
/// call sites: onboarding step 6 writes the extracted name onto its
/// fullName field the instant extraction succeeds (see
/// `_ResumeUploadStepState._extract`), so its footer can truthfully say
/// "your name above has been filled in". The post-signup
/// `ResumeImportScreen` applies nothing until the candidate presses
/// Confirm -- at preview time *nothing* is saved yet, name included --
/// so it passes `false` to keep the footer to the plain preview wording
/// regardless of whether a name was found. Defaults to `true` so step 6's
/// call site didn't need to change.
class ResumeExtractionSummary extends StatelessWidget {
  const ResumeExtractionSummary({
    required this.result,
    this.footerAppliesImmediately = true,
    super.key,
  });

  final ResumeParseResult result;
  final bool footerAppliesImmediately;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.onboardingResumeSummaryHeading,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          if (result.requiresCandidateReview)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                l10n.onboardingResumeReviewWarning,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (result.isEffectivelyEmpty)
            Text(l10n.onboardingResumeEmptyState)
          else ...[
            _scalarRow(
              context,
              l10n.onboardingFullNameFieldLabel,
              result.fullName,
            ),
            _scalarRow(context, l10n.onboardingResumeFieldPhone, result.phone),
            _scalarRow(context, l10n.onboardingResumeFieldEmail, result.email),
            _scalarRow(context, l10n.onboardingResumeFieldCity, result.city),
            _scalarRow(
              context,
              l10n.onboardingResumeFieldHeadline,
              result.headline,
            ),
            _scalarRow(
              context,
              l10n.onboardingResumeFieldExperience,
              result.yearsOfExperience,
            ),
            if (result.skills.isNotEmpty)
              _scalarRow(
                context,
                l10n.onboardingResumeFieldSkills,
                result.skills.join(', '),
              ),
            if (result.education.isNotEmpty)
              _listSection(context, l10n.onboardingResumeFieldEducation, [
                for (final entry in result.education)
                  [
                        entry.degree,
                        entry.fieldOfStudy,
                      ].where((s) => s.isNotEmpty).join(', ').isEmpty
                      ? entry.institution
                      : '${[entry.degree, entry.fieldOfStudy].where((s) => s.isNotEmpty).join(', ')} · ${entry.institution}',
              ]),
            if (result.workExperience.isNotEmpty)
              _listSection(context, l10n.onboardingResumeFieldWorkHistory, [
                for (final entry in result.workExperience)
                  '${entry.title} · ${entry.company}',
              ]),
            if (result.certifications.isNotEmpty)
              _listSection(
                context,
                l10n.profileDetailsCertificationsSectionTitle,
                [for (final entry in result.certifications) entry.name],
              ),
            if (result.projects.isNotEmpty)
              _listSection(context, l10n.profileDetailsProjectsSectionTitle, [
                for (final entry in result.projects) entry.title,
              ]),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            footerAppliesImmediately && result.fullName.isNotEmpty
                ? l10n.onboardingResumeFooterNameFilled
                : l10n.onboardingResumeFooterPreviewOnly,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scalarRow(BuildContext context, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value),
        ],
      ),
    );
  }

  Widget _listSection(BuildContext context, String label, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          for (final item in items) Text('• $item'),
        ],
      ),
    );
  }
}
