import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_progress.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_status_banner.dart';
import '../domain/voice_interview.dart';
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
  String? _message;

  @override
  void dispose() {
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
      Text(question.text, style: Theme.of(context).textTheme.headlineSmall),
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
      Semantics(
        liveRegion: true,
        label: 'Recording is active',
        child: const AppCard(
          backgroundColor: AppColors.errorSoft,
          child: Column(
            children: [
              Icon(Icons.mic, color: AppColors.error, size: 48),
              SizedBox(height: AppSpacing.sm),
              Text(
                'Recording…',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(question.text, style: Theme.of(context).textTheme.titleLarge),
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
  );

  Future<void> _stopRecording() => _run(
    () => ref.read(voiceInterviewControllerProvider.notifier).stopRecording(),
    onSuccess: _transcriptController.clear,
  );

  Future<void> _cancelRecording() => _run(
    () => ref.read(voiceInterviewControllerProvider.notifier).cancelRecording(),
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
