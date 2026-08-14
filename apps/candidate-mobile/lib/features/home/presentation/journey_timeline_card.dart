import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/home_dashboard_repository.dart';
import 'upcoming_interview_card.dart' show formatInterviewWhen;

/// Replaces the old single-pathway progress row with the four checkpoints a
/// candidate actually crosses on the way to a job: Training, Certification,
/// Applications, Interview.
///
/// Each checkpoint's status is read from its own field on [HomeDashboard] --
/// they are deliberately independent rather than gated on one another (e.g.
/// Applications can already be active while Certification hasn't started),
/// matching how candidates in this program actually move: many apply for
/// roles while still completing training, rather than strictly in sequence.
///
/// The whole card is a single tap target to the pathway, not four separately
/// routed checkpoints -- only Training (pathway) and Interview (voice
/// practice) have an existing Home-level navigation callback today, and
/// splitting one row into two tap targets and two dead ones would be a worse
/// affordance than one consistent tap everywhere.
///
/// [HomeDashboard.certificationStatus] and
/// [HomeDashboard.applicationsSentThisMonth] are mock-only fields today, the
/// same as every other field this screen renders -- see that class's doc
/// comment for the backend gap each one represents.
class JourneyTimelineCard extends StatelessWidget {
  const JourneyTimelineCard({
    required this.dashboard,
    required this.onTap,
    super.key,
  });

  final HomeDashboard dashboard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final checkpoints = _buildCheckpoints(l10n, isHindi);

    // Composed from the checkpoints' own already-localized title/subtitle
    // strings, the same way _ShortcutRow builds its label -- not a new ARB
    // key, since the combinatorics of four independent tri-state subtitles
    // would make one translatable sentence unreadable to translate correctly.
    final semanticLabel = checkpoints
        .map((checkpoint) => '${checkpoint.title}: ${checkpoint.subtitle}')
        .join('. ');

    return AppCard(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < checkpoints.length; i++)
            _JourneyCheckpointRow(
              checkpoint: checkpoints[i],
              isLast: i == checkpoints.length - 1,
            ),
        ],
      ),
    );
  }

  List<_Checkpoint> _buildCheckpoints(AppLocalizations l10n, bool isHindi) {
    final pathway = dashboard.pathway;
    final trainingState = pathway == null
        ? _CheckpointState.pending
        : pathway.remainingUnits == 0
        ? _CheckpointState.done
        : pathway.completedUnits > 0
        ? _CheckpointState.active
        : _CheckpointState.pending;
    final trainingSubtitle = pathway == null
        ? l10n.homeJourneyTrainingNotStarted
        : l10n.homePathwayLessons(pathway.completedUnits, pathway.totalUnits);

    final certState = switch (dashboard.certificationStatus) {
      CertificationJourneyStatus.notStarted => _CheckpointState.pending,
      CertificationJourneyStatus.inProgress => _CheckpointState.active,
      CertificationJourneyStatus.passed => _CheckpointState.done,
    };
    final certSubtitle = switch (dashboard.certificationStatus) {
      CertificationJourneyStatus.notStarted =>
        l10n.homeJourneyCertificationNotStarted,
      CertificationJourneyStatus.inProgress =>
        l10n.homeJourneyCertificationInProgress,
      CertificationJourneyStatus.passed => l10n.homeJourneyCertificationPassed,
    };

    final applicationsCount = dashboard.applicationsSentThisMonth;
    final applicationsState = applicationsCount > 0
        ? _CheckpointState.active
        : _CheckpointState.pending;

    final interview = dashboard.nextInterview;
    final interviewState = interview == null
        ? _CheckpointState.pending
        : _CheckpointState.active;
    final interviewSubtitle = interview == null
        ? l10n.homeJourneyInterviewPending
        : '${formatInterviewWhen(interview.scheduledAt, isHindi)} · '
              '${interview.location}';

    return [
      _Checkpoint(
        icon: Icons.menu_book_outlined,
        title: l10n.homeJourneyTrainingLabel,
        subtitle: trainingSubtitle,
        state: trainingState,
      ),
      _Checkpoint(
        icon: Icons.workspace_premium_outlined,
        title: l10n.homeJourneyCertificationLabel,
        subtitle: certSubtitle,
        state: certState,
      ),
      _Checkpoint(
        icon: Icons.send_outlined,
        title: l10n.homeJourneyApplicationsLabel,
        subtitle: l10n.homeJourneyApplicationsSubtitle(applicationsCount),
        state: applicationsState,
      ),
      _Checkpoint(
        icon: Icons.event_outlined,
        title: l10n.homeJourneyInterviewLabel,
        subtitle: interviewSubtitle,
        state: interviewState,
      ),
    ];
  }
}

enum _CheckpointState { pending, active, done }

class _Checkpoint {
  const _Checkpoint({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _CheckpointState state;
}

/// One row of the timeline: a status dot on the left connected to the next
/// row by a vertical rule, and the checkpoint's title/subtitle on the right.
class _JourneyCheckpointRow extends StatelessWidget {
  const _JourneyCheckpointRow({required this.checkpoint, required this.isLast});

  final _Checkpoint checkpoint;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (
      Color dotBackground,
      Color dotForeground,
      Border? dotBorder,
    ) = switch (checkpoint.state) {
      _CheckpointState.done => (AppColors.brand, AppColors.surface, null),
      _CheckpointState.active => (
        AppColors.accentSoft,
        AppColors.accent,
        Border.all(color: AppColors.accent, width: 1.5),
      ),
      _CheckpointState.pending => (
        AppColors.surfaceMuted,
        AppColors.inkMuted,
        null,
      ),
    };

    // IntrinsicHeight, not a bare Row: the left column's connecting line
    // uses Expanded to stretch to the row's height, but Row itself imposes
    // no height constraint on its children -- without this, that Expanded
    // has nothing to expand within and layout throws.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotBackground,
                  border: dotBorder,
                ),
                child: Icon(
                  checkpoint.state == _CheckpointState.done
                      ? Icons.check_rounded
                      : checkpoint.icon,
                  size: 14,
                  color: dotForeground,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxs,
                    ),
                    color: AppColors.surfaceMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : AppSpacing.md,
                // Nudges the text to sit level with the dot's centre rather
                // than its top edge.
                top: 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    checkpoint.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    checkpoint.subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
