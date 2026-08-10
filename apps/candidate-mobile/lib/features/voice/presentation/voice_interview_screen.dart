import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_progress.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_status_banner.dart';
import '../domain/voice_interview.dart';
import 'answer_pacing_track.dart';
import 'voice_interview_controller.dart';

class VoiceInterviewScreen extends ConsumerStatefulWidget {
  const VoiceInterviewScreen({super.key});

  @override
  ConsumerState<VoiceInterviewScreen> createState() =>
      _VoiceInterviewScreenState();
}

class _VoiceInterviewScreenState extends ConsumerState<VoiceInterviewScreen> {
  final _transcriptController = TextEditingController();
  bool _recordingConsent = false;
  bool _transcriptionConsent = false;
  bool _evaluationConsent = false;
  bool _employerSharingConsent = false;
  bool _busy = false;

  /// Ticks only while a recording is in flight. The capture layer reports
  /// duration once, at stop; the candidate needs it continuously, so the
  /// screen keeps its own clock and the two are reconciled by the repository's
  /// stopwatch when the answer is saved.
  ///
  /// A notifier rather than `setState`: only the gauge changes once a second,
  /// and rebuilding the whole recording page at 1Hz to move one bar is work
  /// the cheapest handsets we target can least afford.
  Timer? _tick;
  final _elapsed = ValueNotifier<Duration>(Duration.zero);

  void _startTicking() {
    _tick?.cancel();
    _elapsed.value = Duration.zero;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _elapsed.value += const Duration(seconds: 1);
    });
  }

  void _stopTicking() {
    _tick?.cancel();
    _tick = null;
  }

  String? _message;

  @override
  void dispose() {
    _tick?.cancel();
    _elapsed.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interview = ref.watch(voiceInterviewControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Voice interview practice')),
      body: interview.when(
        loading: () => const AppStateView(
          icon: Icons.mic_none_outlined,
          title: 'Loading voice practice',
          message: 'Restoring your consent and saved interview turns.',
        ),
        error: (error, stackTrace) => AppErrorState(
          title: 'Voice practice could not be loaded',
          message: error is AppFailure
              ? error.message
              : 'Your secure voice session is temporarily unavailable.',
          onAction: () => ref.invalidate(voiceInterviewControllerProvider),
        ),
        data: _buildState,
      ),
    );
  }

  Widget _buildState(VoiceInterviewState state) {
    return switch (state.status) {
      VoiceInterviewStatus.consent => _buildConsent(),
      VoiceInterviewStatus.microphoneCheck => _buildMicrophoneCheck(state),
      VoiceInterviewStatus.microphoneReady => _buildQuestion(state),
      VoiceInterviewStatus.recording => _buildRecording(state),
      VoiceInterviewStatus.transcriptReview => _buildTranscriptReview(state),
      VoiceInterviewStatus.completed => _buildFeedback(state),
    };
  }

  Widget _page(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.md,
      AppSpacing.xl,
      AppSpacing.xxl,
    ),
    children: children,
  );

  Widget _buildConsent() {
    return _page([
      const AppOfflineBanner(
        message:
            'Recorded turns are kept locally and queued. Upload needs a configured secure media service.',
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(
        'Practise a recorded logistics interview',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: AppSpacing.sm),
      const Text(
        'Three short questions • about 5 minutes. You review every transcript before feedback.',
      ),
      const SizedBox(height: AppSpacing.lg),
      const AppCard(
        backgroundColor: AppColors.infoSoft,
        child: Text(
          'This development evaluator uses only transcript text. It never scores accent, pitch, emotion, appearance, personality, caste, religion, gender, disability, or device quality. It cannot reject you or promise employment.',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      _consentTile(
        title: 'Allow recording for this practice session',
        value: _recordingConsent,
        onChanged: (value) => setState(() => _recordingConsent = value),
      ),
      _consentTile(
        title: 'Allow transcription and transcript review',
        value: _transcriptionConsent,
        onChanged: (value) => setState(() => _transcriptionConsent = value),
      ),
      _consentTile(
        title: 'Allow structured coaching evaluation',
        value: _evaluationConsent,
        onChanged: (value) => setState(() => _evaluationConsent = value),
      ),
      _consentTile(
        title: 'Allow future employer sharing',
        subtitle:
            'Optional and revocable. No employer receives this development result.',
        value: _employerSharingConsent,
        onChanged: (value) => setState(() => _employerSharingConsent = value),
      ),
      if (_message != null) _errorText(_message!),
      const SizedBox(height: AppSpacing.md),
      AppButton(
        label: 'Continue to microphone check',
        isLoading: _busy,
        onPressed: _busy ? null : _acceptConsent,
      ),
    ]);
  }

  Widget _consentTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? subtitle,
  }) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    value: value,
    onChanged: (selected) => onChanged(selected ?? false),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
  );

  Widget _buildMicrophoneCheck(VoiceInterviewState state) {
    return _page([
      Text(
        'Microphone readiness',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: AppSpacing.sm),
      const Text(
        'Saksham asks for microphone access only after you press the button below. Recording stops between every answer.',
      ),
      const SizedBox(height: AppSpacing.lg),
      const AppCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.headset_mic_outlined),
          title: Text('Quick device check'),
          subtitle: Text(
            'Use a quiet place if possible. Hindi, Hinglish and code-switching are welcome.',
          ),
        ),
      ),
      if (state.technicalNotice != null) ...[
        const SizedBox(height: AppSpacing.md),
        AppOfflineBanner(message: state.technicalNotice!),
      ],
      if (_message != null) _errorText(_message!),
      const SizedBox(height: AppSpacing.lg),
      AppButton(
        label: 'Allow microphone and continue',
        leadingIcon: Icons.mic_none_outlined,
        isLoading: _busy,
        onPressed: _busy ? null : _checkMicrophone,
      ),
    ]);
  }

  Widget _buildQuestion(VoiceInterviewState state) {
    final question = voiceInterviewQuestions[state.currentQuestionIndex];
    return _page([
      AppProgress(
        value: state.currentQuestionIndex / voiceInterviewQuestions.length,
        label:
            'Question ${state.currentQuestionIndex + 1} of ${voiceInterviewQuestions.length}',
      ),
      if (state.pendingUploadCount > 0) ...[
        const SizedBox(height: AppSpacing.md),
        AppPendingSyncBanner(pendingCount: state.pendingUploadCount),
      ],
      if (state.technicalNotice != null) ...[
        const SizedBox(height: AppSpacing.md),
        AppOfflineBanner(message: state.technicalNotice!),
      ],
      const SizedBox(height: AppSpacing.lg),
      Text(
        question.category,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.brand,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: AppSpacing.xxs),
      Text(question.text, style: Theme.of(context).textTheme.headlineSmall),
      if (question.guidance != null) ...[
        const SizedBox(height: AppSpacing.sm),
        // Shown, not withheld: someone practising alone has no interviewer to
        // read, and the point is to build the answer rather than test them.
        AppCard(
          backgroundColor: AppColors.infoSoft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: AppColors.info,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  question.guidance!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.info),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.sm),
      const Text(
        'Think briefly, then answer naturally. You can cancel and retry without penalty.',
      ),
      if (_message != null) _errorText(_message!),
      const SizedBox(height: AppSpacing.xl),
      AppButton(
        label: 'Start recording',
        leadingIcon: Icons.mic,
        isLoading: _busy,
        semanticLabel:
            'Start recording answer ${state.currentQuestionIndex + 1}',
        onPressed: _busy ? null : _startRecording,
      ),
    ]);
  }

  Widget _buildRecording(VoiceInterviewState state) {
    final question = voiceInterviewQuestions[state.currentQuestionIndex];
    return _page([
      // The question stays on screen while they speak. Hiding it is the
      // commonest flaw in practice tools -- a candidate rehearsing alone
      // loses the thread and answers a half-remembered question.
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: AppRadius.largeBorder,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _RecordingDot(active: !_busy),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'REC · ${question.category}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              question.text,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (question.guidance != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                question.guidance!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      ValueListenableBuilder<Duration>(
        valueListenable: _elapsed,
        builder: (context, elapsed, _) => AnswerPacingTrack(elapsed: elapsed),
      ),
      const SizedBox(height: AppSpacing.xl),
      // Stated where the candidate is actually speaking, not filed in a
      // policy page: this is the promise most likely to be doubted at the
      // moment it matters.
      AppCard(
        backgroundColor: AppColors.brandSoft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined, size: 18, color: AppColors.brand),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Aapki baat, safai aur dhaancha dekha jaata hai. '
                'Lehja ya accent kabhi score nahi hota.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.brandDark),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      AppButton(
        label: 'Stop and review transcript',
        leadingIcon: Icons.stop_circle_outlined,
        isLoading: _busy,
        onPressed: _busy ? null : _stopRecording,
      ),
      const SizedBox(height: AppSpacing.sm),
      AppButton(
        label: 'Cancel this recording',
        variant: AppButtonVariant.secondary,
        onPressed: _busy ? null : _cancelRecording,
      ),
    ]);
  }

  Widget _buildTranscriptReview(VoiceInterviewState state) {
    final answer = state.answers.last;
    return _page([
      Text(
        'Review your transcript',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Recorded locally • ${answer.durationSeconds} seconds. A transcription provider is not connected in this development build, so type or correct what you said before continuing.',
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _transcriptController,
        minLines: 5,
        maxLines: 9,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Candidate-reviewed transcript',
          hintText: 'Type what you said in English, Hindi, or Hinglish',
          alignLabelWithHint: true,
        ),
      ),
      if (_message != null) _errorText(_message!),
      const SizedBox(height: AppSpacing.lg),
      AppButton(
        label: state.currentQuestionIndex + 1 == voiceInterviewQuestions.length
            ? 'Finish and view feedback'
            : 'Save transcript and continue',
        isLoading: _busy,
        onPressed: _busy ? null : _submitTranscript,
      ),
    ]);
  }

  Widget _buildFeedback(VoiceInterviewState state) {
    final evaluation = state.evaluation!;
    return _page([
      const AppCard(
        backgroundColor: AppColors.warningSoft,
        child: Text(
          'Development coaching only. A human must review this low-confidence result before any consequential use. Employers cannot use it for automatic rejection.',
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(
        '${evaluation.totalScore}%',
        style: Theme.of(context).textTheme.displaySmall,
        textAlign: TextAlign.center,
      ),
      const Text('Local coaching estimate', textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.lg),
      for (final dimension in evaluation.dimensions) ...[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${dimension.dimension} • ${dimension.score}%',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(dimension.explanation),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      AppCard(
        backgroundColor: AppColors.infoSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Next improvement',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(evaluation.improvement),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Confidence ${(evaluation.confidence * 100).round()}% • ${evaluation.rubricVersion}',
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      if (state.humanReviewRequested)
        const AppCard(
          backgroundColor: AppColors.successSoft,
          child: Text(
            'Human review requested. The future admin queue will show this request without changing your reliability.',
          ),
        )
      else
        AppButton(
          label: 'Request human review',
          variant: AppButtonVariant.secondary,
          isLoading: _busy,
          onPressed: _busy ? null : _requestHumanReview,
        ),
      const SizedBox(height: AppSpacing.sm),
      AppButton(
        label: 'Delete local audio and feedback',
        variant: AppButtonVariant.destructive,
        onPressed: _busy ? null : _confirmDelete,
      ),
    ]);
  }

  Widget _errorText(String message) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md),
    child: Text(message, style: const TextStyle(color: AppColors.error)),
  );

  Future<void> _run(
    Future<AppFailure?> Function() action, {
    VoidCallback? onSuccess,
  }) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final failure = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = failure?.message;
    });
    if (failure == null) onSuccess?.call();
  }

  Future<void> _acceptConsent() => _run(
    () => ref
        .read(voiceInterviewControllerProvider.notifier)
        .acceptConsent(
          recording: _recordingConsent,
          transcription: _transcriptionConsent,
          evaluation: _evaluationConsent,
          employerSharing: _employerSharingConsent,
        ),
  );

  Future<void> _checkMicrophone() => _run(
    () => ref.read(voiceInterviewControllerProvider.notifier).checkMicrophone(),
  );

  Future<void> _startRecording() => _run(
    () => ref.read(voiceInterviewControllerProvider.notifier).startRecording(),
    onSuccess: _startTicking,
  );

  Future<void> _stopRecording() => _run(
    () => ref.read(voiceInterviewControllerProvider.notifier).stopRecording(),
    onSuccess: () {
      _stopTicking();
      _transcriptController.clear();
    },
  );

  Future<void> _cancelRecording() => _run(
    () => ref.read(voiceInterviewControllerProvider.notifier).cancelRecording(),
    onSuccess: _stopTicking,
  );

  Future<void> _submitTranscript() => _run(
    () => ref
        .read(voiceInterviewControllerProvider.notifier)
        .submitTranscript(_transcriptController.text),
    onSuccess: _transcriptController.clear,
  );

  Future<void> _requestHumanReview() => _run(
    () => ref
        .read(voiceInterviewControllerProvider.notifier)
        .requestHumanReview(),
  );

  Future<void> _confirmDelete() async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Delete this voice practice?',
      message:
          'Local audio, transcripts and development feedback will be removed from this device.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed) {
      await _run(
        () => ref
            .read(voiceInterviewControllerProvider.notifier)
            .deleteInterview(),
      );
    }
  }
}

/// A quiet pulse, the one piece of motion on this screen. It reports a single
/// fact -- the microphone is live -- which is exactly the kind of state worth
/// animating. Held still under prefers-reduced-motion, where the colour and
/// the REC label still carry the meaning.
class _RecordingDot extends StatefulWidget {
  const _RecordingDot({required this.active});

  final bool active;

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still =
        MediaQuery.maybeDisableAnimationsOf(context) ?? !widget.active;
    return SizedBox(
      width: 10,
      height: 10,
      child: still
          ? const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            )
          : FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0.35).animate(_controller),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
    );
  }
}
