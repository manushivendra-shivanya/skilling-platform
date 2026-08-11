import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../learning/presentation/learning_controller.dart';
import '../../sector_pack/application/active_sector_pack_provider.dart';
import '../../sector_pack/domain/sector_pack.dart';
import '../../sector_pack/presentation/sector_credential_card.dart';
import '../../sector_pack/presentation/sector_pack_icons.dart';
import '../../sector_pack/presentation/sector_signal_dot.dart';
import '../domain/certification_exam_repository.dart';
import 'certification_exam_controller.dart';
import 'certification_exam_screen.dart';

/// Eligibility rule: the certification exam unlocks once every lesson unit
/// is completed. Shared between this section and the Learn tab's segmented
/// state-readout bar (`learn_and_practice_screen.dart`) so both read the
/// exact same rule from one place.
///
/// TODO(product): this rule was proposed during this pass and has not had
/// explicit product sign-off yet -- revisit if a different eligibility bar
/// (e.g. a subset of units, a minimum practice count) is decided on.
bool isCertificationEligible(LearningState learning) =>
    learning.completedIds.length == learning.units.length;

/// The Learn tab's Certification section: a single formal, timed exam,
/// distinct from the unlimited casual practice offered elsewhere. Unlike
/// that practice content (practice-only until explicitly submitted for
/// evidence), passing this exam always produces Career Passport evidence.
///
/// Rendered as its own segmented tab under Learn (see
/// `learn_and_practice_screen.dart`) rather than scrolled-to at the bottom
/// of Lessons -- promoted per the "Certification as its own tab" proposal
/// in the published Shift Floor coverage mock, since the previous
/// placement buried it below every lesson unit and the entire clips
/// section.
class CertificationExamSection extends ConsumerWidget {
  const CertificationExamSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examState = ref.watch(certificationExamControllerProvider);
    final learningState = ref.watch(learningControllerProvider);
    final pack = ref.watch(activeSectorPackProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        112,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Warehouse Operations Certification',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text(
            'प्रमाणन (सर्टिफिकेशन)',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'A formal, timed exam covering the full warehouse process. Pass '
            'it to add verified Career Passport evidence for every '
            'competency it covers.',
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Passing adds real Career Passport evidence -- visible to an '
              'employer only if you choose to share it, same as everywhere '
              'else.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildBody(ref, learningState, examState, pack),
        ],
      ),
    );
  }

  Widget _buildBody(
    WidgetRef ref,
    AsyncValue<LearningState> learningState,
    AsyncValue<CertificationExamState> examState,
    SectorPack pack,
  ) {
    final error = learningState.error ?? examState.error;
    if (error != null) {
      return AppErrorState(
        title: 'Certification exam could not be loaded',
        message: error is AppFailure
            ? error.message
            : 'The exam is temporarily unavailable.',
        onAction: () {
          ref.read(learningControllerProvider.notifier).retry();
          ref.read(certificationExamControllerProvider.notifier).retry();
        },
      );
    }
    final learning = learningState.valueOrNull;
    final exam = examState.valueOrNull;
    if (learning == null || exam == null) {
      return const AppSkeleton(height: 220);
    }
    return _CredentialSection(pack: pack, learning: learning, exam: exam);
  }
}

class _CredentialSection extends StatelessWidget {
  const _CredentialSection({
    required this.pack,
    required this.learning,
    required this.exam,
  });

  final SectorPack pack;
  final LearningState learning;
  final CertificationExamState exam;

  @override
  Widget build(BuildContext context) {
    final data = exam.exam;
    final minutes = (data.timeLimit.inSeconds / 60).ceil();
    final lastAttempt = exam.lastAttempt;
    final passed = exam.lastAttemptPassed;
    final eligible = isCertificationEligible(learning);

    final SectorGlyph glyph;
    final String statusLabel;
    final SectorSignalState statusState;
    String? attemptText;
    SectorSignalState? attemptState;
    String? eligibilityLabel;
    double? eligibilityFraction;
    final String ctaLabel;
    final bool ctaEnabled;
    final String semanticLabel;

    if (!eligible) {
      glyph = SectorGlyph.lock;
      statusLabel = 'LOCKED';
      statusState = SectorSignalState.locked;
      eligibilityLabel =
          '${learning.completedIds.length} / ${learning.units.length} LESSONS CLEARED';
      eligibilityFraction = learning.units.isEmpty
          ? 0
          : learning.completedIds.length / learning.units.length;
      ctaLabel = 'Clear all lessons to unlock';
      ctaEnabled = false;
      semanticLabel =
          '${data.title}. Locked. ${learning.completedIds.length} of '
          '${learning.units.length} lessons cleared.';
    } else if (lastAttempt == null) {
      glyph = SectorGlyph.check;
      statusLabel = 'ELIGIBLE';
      statusState = SectorSignalState.cleared;
      ctaLabel = 'Start certification exam';
      ctaEnabled = true;
      semanticLabel = '${data.title}. Eligible to start.';
    } else if (passed) {
      glyph = SectorGlyph.check;
      statusLabel = 'VERIFIED';
      statusState = SectorSignalState.cleared;
      attemptText =
          'Passed with ${lastAttempt.scorePercent}% -- Career Passport updated.';
      attemptState = SectorSignalState.cleared;
      ctaLabel = 'Retake exam';
      ctaEnabled = true;
      semanticLabel =
          '${data.title}. Verified. Passed with '
          '${lastAttempt.scorePercent} percent.';
    } else {
      glyph = SectorGlyph.cross;
      statusLabel = 'LOCKED';
      statusState = SectorSignalState.locked;
      final retakeAt = lastAttempt.submittedAt.add(
        certificationExamRetakeCooldown,
      );
      final canRetakeNow = DateTime.now().toUtc().isAfter(retakeAt);
      attemptText =
          'Last attempt: ${lastAttempt.scorePercent}%, below the '
          '${data.passThresholdPercent}% pass mark.'
          '${canRetakeNow ? '' : ' You can retake this exam after ${_formatTime(retakeAt)}.'}';
      attemptState = SectorSignalState.locked;
      ctaLabel = 'Retake exam';
      ctaEnabled = true;
      semanticLabel =
          '${data.title}. Last attempt ${lastAttempt.scorePercent} percent, '
          'below the ${data.passThresholdPercent} percent pass mark.'
          '${canRetakeNow ? '' : ' Retake unlocks at ${_formatTime(retakeAt)}.'}';
    }

    return SectorCredentialCard(
      pack: pack,
      orgLine:
          '${pack.displayName.toUpperCase()} · ${data.questions.length}Q · ~$minutes MIN',
      levelLabel: 'PASS ${data.passThresholdPercent}%',
      glyph: glyph,
      credentialName: data.title,
      subtitle: pack.pilotRole,
      statusLabel: statusLabel,
      statusState: statusState,
      barcodeSeed: '${data.id}-${lastAttempt?.id ?? 'none'}',
      eligibilityLabel: eligibilityLabel,
      eligibilityFraction: eligibilityFraction,
      attemptText: attemptText,
      attemptState: attemptState,
      ctaLabel: ctaLabel,
      ctaEnabled: ctaEnabled,
      semanticLabel: semanticLabel,
      onCta: ctaEnabled
          ? () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => CertificationExamScreen(exam: data),
              ),
            )
          : null,
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
