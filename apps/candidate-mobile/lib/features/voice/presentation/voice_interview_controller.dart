import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/voice_evaluation_engine.dart';
import '../domain/voice_interview.dart';

final voiceInterviewControllerProvider =
    AsyncNotifierProvider<VoiceInterviewController, VoiceInterviewState>(
      VoiceInterviewController.new,
    );

class VoiceInterviewController extends AsyncNotifier<VoiceInterviewState> {
  String? _candidateId;

  @override
  Future<VoiceInterviewState> build() async {
    final sessionResult = await ref
        .read(candidateSessionRepositoryProvider)
        .readSession();
    final session = sessionResult.when(
      success: (value) => value,
      failure: (failure) => throw failure,
    );
    if (session == null || !session.isAuthenticated) {
      throw const AuthenticationFailure(
        'Sign in again to access voice interview practice.',
      );
    }
    _candidateId = session.candidateId;
    final result = await ref
        .read(voiceInterviewRepositoryProvider)
        .load(session.candidateId);
    return result.when(
      success: (value) => value,
      failure: (failure) => throw failure,
    );
  }

  Future<AppFailure?> acceptConsent({
    required bool recording,
    required bool transcription,
    required bool evaluation,
    required bool employerSharing,
  }) async {
    if (!recording || !transcription || !evaluation) {
      return const ValidationFailure(
        'Recording, transcription and evaluation consent are required for this practice interview.',
      );
    }
    final next = VoiceInterviewState(
      sessionId: 'voice-${DateTime.now().microsecondsSinceEpoch}',
      status: VoiceInterviewStatus.microphoneCheck,
      consent: VoiceConsent(
        recording: recording,
        transcription: transcription,
        evaluation: evaluation,
        employerSharing: employerSharing,
        policyVersion: 'voice-practice-consent-v1',
        acceptedAt: DateTime.now().toUtc(),
      ),
    );
    final failure = await _save(next);
    if (failure == null) {
      await ref
          .read(analyticsTrackerProvider)
          .track(AnalyticsEvent.voiceConsentGranted());
    }
    return failure;
  }

  Future<AppFailure?> checkMicrophone() async {
    final capture = ref.read(voiceCaptureRepositoryProvider);
    final result = await capture.requestPermission();
    return result.when(
      success: (granted) {
        if (!granted) {
          state = AsyncData(
            (state.valueOrNull ?? const VoiceInterviewState()).copyWith(
              status: VoiceInterviewStatus.microphoneCheck,
              microphonePermissionGranted: false,
              technicalNotice:
                  'Microphone access was not granted. Open system app permissions if you want to record.',
            ),
          );
          return const PermissionFailure(
            'Microphone access is needed only while recording an answer.',
          );
        }
        return _save(
          (state.valueOrNull ?? const VoiceInterviewState()).copyWith(
            status: VoiceInterviewStatus.microphoneReady,
            microphonePermissionGranted: true,
            clearTechnicalNotice: true,
          ),
        );
      },
      failure: (failure) => failure,
    );
  }

  Future<AppFailure?> startRecording() async {
    final current = state.valueOrNull;
    if (current == null ||
        !current.microphonePermissionGranted ||
        current.sessionId == null) {
      return const PermissionFailure(
        'Complete the microphone check before recording.',
      );
    }
    final question = voiceInterviewQuestions[current.currentQuestionIndex];
    final result = await ref
        .read(voiceCaptureRepositoryProvider)
        .start(sessionId: current.sessionId!, questionId: question.id);
    return result.when(
      success: (_) => _save(
        current.copyWith(
          status: VoiceInterviewStatus.recording,
          clearTechnicalNotice: true,
        ),
      ),
      failure: (failure) => failure,
    );
  }

  Future<AppFailure?> stopRecording() async {
    final current = state.valueOrNull;
    if (current == null || current.status != VoiceInterviewStatus.recording) {
      return const ValidationFailure('No recording is currently active.');
    }
    final capture = ref.read(voiceCaptureRepositoryProvider);
    final uploadQueue = ref.read(resumableMediaUploadRepositoryProvider);
    final analytics = ref.read(analyticsTrackerProvider);
    final result = await capture.stop();
    return result.when(
      success: (recording) async {
        final question = voiceInterviewQuestions[current.currentQuestionIndex];
        final answer = VoiceAnswer(
          questionId: question.id,
          transcript: '',
          localAudioPath: recording.path,
          durationSeconds: recording.durationSeconds,
          recordedAt: DateTime.now().toUtc(),
        );
        final next = current.copyWith(
          status: VoiceInterviewStatus.transcriptReview,
          answers: [...current.answers, answer],
          pendingUploadCount: current.pendingUploadCount + 1,
        );
        final failure = await _save(next);
        if (failure != null) return failure;
        await uploadQueue.queue(
          sessionId: current.sessionId!,
          questionId: question.id,
          localPath: recording.path,
        );
        await analytics.track(
          AnalyticsEvent.voiceTurnRecorded(current.currentQuestionIndex + 1),
        );
        return null;
      },
      failure: (failure) => failure,
    );
  }

  Future<AppFailure?> cancelRecording() async {
    final current = state.valueOrNull;
    if (current == null) return null;
    await ref.read(voiceCaptureRepositoryProvider).cancel();
    return _save(
      current.copyWith(
        status: VoiceInterviewStatus.microphoneReady,
        technicalNotice:
            'Recording cancelled. No feedback or reliability signal was changed.',
      ),
    );
  }

  Future<AppFailure?> submitTranscript(String transcript) async {
    final current = state.valueOrNull;
    final trimmed = transcript.trim();
    if (current == null ||
        current.status != VoiceInterviewStatus.transcriptReview ||
        current.answers.isEmpty) {
      return const ValidationFailure('Record an answer before reviewing it.');
    }
    if (trimmed.split(RegExp(r'\s+')).length < 3) {
      return const ValidationFailure(
        'Add at least a short reviewable transcript before continuing.',
      );
    }
    final answers = [...current.answers];
    answers[answers.length - 1] = answers.last.copyWith(transcript: trimmed);
    final nextQuestion = current.currentQuestionIndex + 1;
    if (nextQuestion < voiceInterviewQuestions.length) {
      return _save(
        current.copyWith(
          status: VoiceInterviewStatus.microphoneReady,
          answers: answers,
          currentQuestionIndex: nextQuestion,
          clearTechnicalNotice: true,
        ),
      );
    }
    final evaluation = const VoiceEvaluationEngine().evaluate(answers);
    final failure = await _save(
      current.copyWith(
        status: VoiceInterviewStatus.completed,
        answers: answers,
        currentQuestionIndex: nextQuestion,
        evaluation: evaluation,
        clearTechnicalNotice: true,
      ),
    );
    if (failure == null) {
      await ref
          .read(analyticsTrackerProvider)
          .track(AnalyticsEvent.voiceFeedbackReady(evaluation.rubricVersion));
    }
    return failure;
  }

  Future<AppFailure?> requestHumanReview() async {
    final current = state.valueOrNull;
    if (current == null || current.evaluation == null) {
      return const ValidationFailure(
        'Complete the interview before requesting review.',
      );
    }
    final failure = await _save(current.copyWith(humanReviewRequested: true));
    if (failure == null) {
      await ref
          .read(analyticsTrackerProvider)
          .track(AnalyticsEvent.voiceHumanReviewRequested());
    }
    return failure;
  }

  Future<AppFailure?> deleteInterview() async {
    final current = state.valueOrNull;
    final candidateId = _candidateId;
    if (candidateId == null) {
      return const AuthenticationFailure('Sign in again to delete data.');
    }
    final capture = ref.read(voiceCaptureRepositoryProvider);
    for (final answer in current?.answers ?? const <VoiceAnswer>[]) {
      await capture.deleteLocalFile(answer.localAudioPath);
    }
    final result = await ref
        .read(voiceInterviewRepositoryProvider)
        .delete(candidateId);
    return result.when(
      success: (_) {
        state = const AsyncData(VoiceInterviewState());
        return null;
      },
      failure: (failure) => failure,
    );
  }

  Future<AppFailure?> _save(VoiceInterviewState next) async {
    final candidateId = _candidateId;
    if (candidateId == null) {
      return const AuthenticationFailure('Sign in again to save progress.');
    }
    state = AsyncData(next);
    final result = await ref
        .read(voiceInterviewRepositoryProvider)
        .save(candidateId, next);
    return result.when(success: (_) => null, failure: (failure) => failure);
  }
}
