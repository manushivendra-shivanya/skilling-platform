import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/certification_exam.dart';
import '../domain/certification_exam_attempt.dart';
import 'certification_exam_controller.dart';
import 'certification_exam_result_screen.dart';

/// Answer recorded for a question the candidate never reached before the
/// timer ran out. Never matches a real [ExamAnswerOption.id], so it always
/// scores as incorrect -- lets a timed-out attempt still satisfy
/// [CertificationExamAttemptRepository.recordAttempt]'s "exactly one
/// response per question" requirement without inventing a fake answer.
const unansweredOptionId = '__unanswered__';

/// Timed question flow for a [CertificationExam]: single-select MCQ, free
/// navigation between questions while time remains, no per-question
/// right/wrong feedback (unlike the micro-lesson practice question) since
/// this is a formal assessment, not practice.
class CertificationExamScreen extends ConsumerStatefulWidget {
  const CertificationExamScreen({required this.exam, super.key});

  final CertificationExam exam;

  @override
  ConsumerState<CertificationExamScreen> createState() =>
      _CertificationExamScreenState();
}

class _CertificationExamScreenState
    extends ConsumerState<CertificationExamScreen> {
  late final DateTime _startedAt;
  late Duration _remaining;
  Timer? _timer;
  int _currentIndex = 0;
  final Map<String, String> _selections = {};
  bool _isSubmitting = false;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now().toUtc();
    _remaining = widget.exam.timeLimit;
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer timer) {
    if (_remaining <= const Duration(seconds: 1)) {
      timer.cancel();
      setState(() => _remaining = Duration.zero);
      _submit(autoSubmittedByTimeout: true);
      return;
    }
    setState(() => _remaining -= const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _submit({bool autoSubmittedByTimeout = false}) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    final candidateId = await _readCandidateId();
    if (!mounted) return;
    if (candidateId == null) {
      setState(() {
        _isSubmitting = false;
        _submissionError = 'Sign in again to record this attempt.';
      });
      return;
    }

    final submittedAt = DateTime.now().toUtc();
    final responses = [
      for (final question in widget.exam.questions)
        QuestionResponse(
          questionId: question.id,
          competencyId: question.competencyId,
          selectedOptionId: _selections[question.id] ?? unansweredOptionId,
          correctOptionId: question.correctOptionId,
        ),
    ];

    final result = await ref
        .read(certificationExamAttemptRepositoryProvider)
        .recordAttempt(
          candidateId: candidateId,
          exam: widget.exam,
          responses: responses,
          startedAt: _startedAt,
          submittedAt: submittedAt,
        );
    if (!mounted) return;
    result.when(
      success: (attempt) {
        ref.invalidate(certificationExamControllerProvider);
        Navigator.of(context, rootNavigator: true).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => CertificationExamResultScreen(
              exam: widget.exam,
              attempt: attempt,
            ),
          ),
        );
      },
      failure: (failure) => setState(() {
        _isSubmitting = false;
        _submissionError = failure.message;
      }),
    );
  }

  Future<String?> _readCandidateId() async {
    final result = await ref
        .read(candidateSessionRepositoryProvider)
        .readSession();
    final session = result.when(
      success: (value) => value,
      failure: (_) => null,
    );
    return session?.isAuthenticated == true ? session!.candidateId : null;
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.exam.questions;
    final question = questions[_currentIndex];
    final answeredCount = _selections.length;
    final allAnswered = answeredCount == questions.length;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Exit exam',
            onPressed: () => _confirmExit(context),
            icon: const Icon(Icons.close),
          ),
          title: Text('Question ${_currentIndex + 1} of ${questions.length}'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Center(child: _TimerLabel(remaining: _remaining)),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / questions.length,
            ),
            const SizedBox(height: AppSpacing.md),
            if (question.context != null) ...[
              Text(
                question.context!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              question.prompt,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final option in question.options) ...[
              AppCard(
                onTap: _isSubmitting
                    ? null
                    : () =>
                          setState(() => _selections[question.id] = option.id),
                semanticLabel:
                    '${option.label}. '
                    '${_selections[question.id] == option.id ? 'Selected' : 'Not selected'}',
                backgroundColor: _selections[question.id] == option.id
                    ? AppColors.brandSoft
                    : AppColors.surface,
                child: Row(
                  children: [
                    Expanded(child: Text(option.label)),
                    Icon(
                      _selections[question.id] == option.id
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: _selections[question.id] == option.id
                          ? AppColors.brand
                          : AppColors.outline,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (_currentIndex > 0)
                  Expanded(
                    child: AppButton(
                      label: 'Previous',
                      variant: AppButtonVariant.secondary,
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _currentIndex -= 1),
                    ),
                  ),
                if (_currentIndex > 0) const SizedBox(width: AppSpacing.sm),
                if (_currentIndex < questions.length - 1)
                  Expanded(
                    child: AppButton(
                      label: 'Next',
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _currentIndex += 1),
                    ),
                  ),
              ],
            ),
            if (_currentIndex == questions.length - 1) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$answeredCount of ${questions.length} questions answered',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: _isSubmitting ? 'Submitting...' : 'Submit exam',
                onPressed: (!allAnswered || _isSubmitting)
                    ? null
                    : () => _submit(),
              ),
            ],
            if (_submissionError != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _submissionError!,
                style: const TextStyle(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit certification exam?'),
        content: const Text(
          'Your progress will be lost and this will not count as an '
          'attempt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (shouldExit == true && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

class _TimerLabel extends StatelessWidget {
  const _TimerLabel({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final label =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
    final isLow = remaining <= const Duration(minutes: 1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timer_outlined,
          size: 18,
          color: isLow ? AppColors.error : AppColors.inkMuted,
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          label,
          style: TextStyle(
            color: isLow ? AppColors.error : AppColors.inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
