import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_button.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../sector_pack/application/active_sector_pack_provider.dart';
import '../../sector_pack/domain/sector_pack.dart';
import '../../sector_pack/presentation/sector_pack_icons.dart';
import '../../sector_pack/presentation/sector_pack_typography.dart';
import '../domain/certification_exam.dart';
import '../domain/certification_exam_attempt.dart';
import 'certification_exam_controller.dart';
import 'certification_exam_result_screen.dart';

/// Muted red the exam timer switches to inside its last minute, on top of
/// the navy app-bar chrome -- traced from the approved
/// `exam-screen-mock.html`'s `.exam-timer.low` (`#E8746A`). Not an
/// `AppColors` token: it's a one-off tone for white-on-navy timer text/icon
/// contrast, distinct from `AppColors.error`'s light-surface red used
/// everywhere else the timer sat before this restyle.
const _timerLowColor = Color(0xFFE8746A);

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
        _submissionError = AppLocalizations.of(context).clipSignInAgain;
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
    final l10n = AppLocalizations.of(context);
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
        _submissionError = failure.localizedMessage(l10n);
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
    final l10n = AppLocalizations.of(context);
    final pack = ref.watch(activeSectorPackProvider);
    final questions = widget.exam.questions;
    final question = questions[_currentIndex];
    final answeredCount = _selections.length;
    final allAnswered = answeredCount == questions.length;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: l10n.examExitTooltip,
            onPressed: () => _confirmExit(context),
            icon: SectorIcon(
              glyph: SectorGlyph.cross,
              color: Colors.white.withValues(alpha: 0.7),
              size: 20,
            ),
          ),
          title: Text(
            l10n.examQuestionCounter(_currentIndex + 1, questions.length),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Center(
                child: _TimerLabel(remaining: _remaining, pack: pack),
              ),
            ),
          ],
          // Thin hazard-amber progress fill directly under the app-bar, per
          // the mock's `.exam-progress-track`/`.exam-progress-fill` -- moved
          // out of the scrollable body (where it lived as a plain Material
          // `LinearProgressIndicator`) so it reads as fixed chrome, same as
          // the navy bar above it.
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / questions.length,
              minHeight: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                pack.signalPalette.active,
              ),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
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
              _ExamOptionCard(
                pack: pack,
                label: option.label,
                selected: _selections[question.id] == option.id,
                onTap: _isSubmitting
                    ? null
                    : () =>
                          setState(() => _selections[question.id] = option.id),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (_currentIndex > 0)
                  Expanded(
                    child: AppButton(
                      label: l10n.examPreviousButton,
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
                      label: l10n.examNextButton,
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
                l10n.examAnsweredCount(answeredCount, questions.length),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: _isSubmitting
                    ? l10n.assessmentSubmittingLabel
                    : l10n.examSubmitButton,
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
    final l10n = AppLocalizations.of(context);
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.examExitDialogTitle),
        content: Text(l10n.examExitDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.examKeepGoingButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.examExitButton),
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
  const _TimerLabel({required this.remaining, required this.pack});

  final Duration remaining;
  final SectorPack pack;

  @override
  Widget build(BuildContext context) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final label =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
    // isLow threshold is unchanged assessment logic -- only the colours it
    // drives are restyled here (hazard-amber normally, muted red in the
    // last minute, per the mock's `.exam-timer`/`.exam-timer.low`). The
    // clock glyph itself stays the bare Material `Icons.timer_outlined`:
    // no clock shape exists in `SectorGlyph`, and the mock is explicit that
    // its 4 existing glyphs (check/cross/radioSelected/radioUnselected)
    // cover everything this restyle needs -- adding a 5th glyph for a
    // decorative timer icon was out of scope.
    final isLow = remaining <= const Duration(minutes: 1);
    final color = isLow ? _timerLowColor : pack.signalPalette.active;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 18, color: color),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// One MCQ answer row -- `pack.primaryAccent`-toned border/tint when
/// selected, drawn [SectorGlyph.radioSelected] / [SectorGlyph.radioUnselected]
/// glyphs instead of `Icons.check_circle` / `Icons.radio_button_unchecked`,
/// same shape as `practice_screen.dart`'s private `_DemoOptionCard` (the
/// mock explicitly reuses that pattern). `onTap` is nullable, unlike
/// `_DemoOptionCard`'s, so a row can be disabled while `_isSubmitting`.
class _ExamOptionCard extends StatelessWidget {
  const _ExamOptionCard({
    required this.pack,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final SectorPack pack;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final surface = Theme.of(context).colorScheme.surface;
    final divider = Theme.of(context).dividerColor;
    final ink = Theme.of(context).colorScheme.onSurface;
    final inkSoft = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: l10n.practiceOptionSemantic(
        label,
        selected ? l10n.practiceOptionSelected : l10n.practiceOptionNotSelected,
      ),
      button: true,
      enabled: onTap != null,
      container: true,
      // excludeSemantics: true hides the descendant Text/icon's own
      // semantics (redundant with `label` above), but it also drops the
      // InkWell's own tap-action semantics -- `onTap` is repeated
      // explicitly on this node to keep it screen-reader-activatable, same
      // fix already shipped on `_DemoOptionCard` in practice_screen.dart.
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected
            ? Color.lerp(surface, pack.primaryAccent, 0.08)
            : surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? pack.primaryAccent : divider,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: SectorPackTypography.bodyRegular(
                        color: ink,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SectorIcon(
                    glyph: selected
                        ? SectorGlyph.radioSelected
                        : SectorGlyph.radioUnselected,
                    color: selected ? pack.primaryAccent : inkSoft,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
