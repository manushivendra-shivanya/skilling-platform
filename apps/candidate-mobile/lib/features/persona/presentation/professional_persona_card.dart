import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../onboarding/domain/candidate_onboarding_draft.dart';

/// A shareable-style summary card built entirely from data the candidate
/// already supplied via onboarding and (optionally) resume-parsing --
/// name, headline, education, experience, and preferred roles. This is
/// the "networking card" the "Build my professional profile"
/// [CandidateGoal] leads towards.
///
/// Deliberately scoped to stay on the right side of
/// docs/00-master-plan.md's "Unverified resume database" non-goal, same
/// sharing-boundary philosophy `CareerPassportSection` already
/// establishes: self-reported content the candidate controls, copied out
/// by the candidate's own action -- never hosted by Flora, never a
/// database anyone can browse or query. No employer, recruiter, or other
/// candidate can see this card unless the candidate themselves pastes it
/// somewhere.
///
/// Shown on the Profile screen only when there's real content to show
/// (a non-empty [CandidateOnboardingDraft.headline]) -- an empty card
/// with just a name would be visual noise, not a networking card.
class ProfessionalPersonaCard extends StatelessWidget {
  const ProfessionalPersonaCard({required this.draft, super.key});

  final CandidateOnboardingDraft draft;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      if (draft.education != null) draft.education!.label,
      if (draft.experience != null) draft.experience!.label,
      for (final role in draft.preferredRoles) role.label,
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Professional persona',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const AppStatusChip(label: 'Self-reported'),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Built from what you told us -- never hosted or shared by '
            'Flora on its own. Copy it to paste into a message, an '
            'application, or your own profile elsewhere.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(draft.fullName, style: Theme.of(context).textTheme.titleMedium),
          if (draft.headline.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(draft.headline),
          ],
          if (draft.city.isNotEmpty || draft.state.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              [
                draft.city,
                draft.state,
              ].where((part) => part.isNotEmpty).join(', '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final label in chips) AppStatusChip(label: label),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Copy persona summary',
            variant: AppButtonVariant.secondary,
            onPressed: () => _copySummary(context),
          ),
        ],
      ),
    );
  }

  Future<void> _copySummary(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _summaryText()));
    if (!context.mounted) return;
    showAppSnackBar(
      context: context,
      message: 'Persona summary copied.',
      tone: AppMessageTone.success,
    );
  }

  String _summaryText() {
    final lines = <String>[draft.fullName];
    if (draft.headline.trim().isNotEmpty) {
      lines.add(draft.headline.trim());
    }
    final location = [
      draft.city,
      draft.state,
    ].where((part) => part.isNotEmpty).join(', ');
    if (location.isNotEmpty) {
      lines.add(location);
    }
    final tags = <String>[
      if (draft.education != null) draft.education!.label,
      if (draft.experience != null) draft.experience!.label,
    ];
    if (tags.isNotEmpty) {
      lines.add(tags.join(' · '));
    }
    if (draft.preferredRoles.isNotEmpty) {
      lines.add(
        'Open to: '
        '${draft.preferredRoles.map((role) => role.label).join(', ')}',
      );
    }
    return lines.join('\n');
  }
}
