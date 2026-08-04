import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../domain/certification_exam_repository.dart';
import 'certification_exam_controller.dart';
import 'certification_exam_screen.dart';

/// "Warehouse Operations Certification" card in the Learn tab: a single
/// formal, timed exam, distinct from the unlimited casual practice offered
/// by [WarehouseClipsSection] above it. Unlike that section's clips
/// (practice-only until explicitly submitted for evidence), passing this
/// exam always produces Career Passport evidence -- so the banner here says
/// so plainly instead of reusing [NotEmployerEvidenceBanner]'s "not
/// evidence yet" framing, which would be inaccurate for this feature.
class CertificationExamSection extends ConsumerWidget {
  const CertificationExamSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(certificationExamControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Warehouse Operations Certification',
          style: Theme.of(context).textTheme.headlineSmall,
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
        state.when(
          loading: () => const AppSkeleton(height: 96),
          error: (error, stackTrace) => AppErrorState(
            title: 'Certification exam could not be loaded',
            message: error is AppFailure
                ? error.message
                : 'The exam is temporarily unavailable.',
            onAction: () =>
                ref.read(certificationExamControllerProvider.notifier).retry(),
          ),
          data: (data) => _ExamCard(state: data),
        ),
      ],
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.state});

  final CertificationExamState state;

  @override
  Widget build(BuildContext context) {
    final exam = state.exam;
    final lastAttempt = state.lastAttempt;
    final minutes = (exam.timeLimit.inSeconds / 60).ceil();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exam.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${exam.questions.length} questions • ~$minutes min • '
            'Pass at ${exam.passThresholdPercent}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (lastAttempt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _LastAttemptSummary(state: state),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: lastAttempt == null
                ? 'Start certification exam'
                : 'Retake exam',
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => CertificationExamScreen(exam: exam),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LastAttemptSummary extends StatelessWidget {
  const _LastAttemptSummary({required this.state});

  final CertificationExamState state;

  @override
  Widget build(BuildContext context) {
    final attempt = state.lastAttempt!;
    final passed = state.lastAttemptPassed;
    final retakeAt = attempt.submittedAt.add(certificationExamRetakeCooldown);
    final canRetakeNow = DateTime.now().toUtc().isAfter(retakeAt);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: passed ? AppColors.successSoft : AppColors.errorSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            passed ? Icons.verified : Icons.cancel,
            color: passed ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              passed
                  ? 'Passed with ${attempt.scorePercent}% -- Career Passport updated.'
                  : 'Last attempt: ${attempt.scorePercent}%, below the '
                        '${state.exam.passThresholdPercent}% pass mark.'
                        '${canRetakeNow ? '' : ' You can retake this exam '
                                  'after ${_formatTime(retakeAt)}.'}',
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
