import 'package:candidate_mobile/core/analytics/analytics_tracker.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_draft.dart';
import 'package:candidate_mobile/features/voice/data/record_voice_capture_repository.dart';
import 'package:candidate_mobile/features/voice/data/secure_voice_interview_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets(
    'candidate records turns, reviews transcripts and requests human review',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final analytics = InMemoryAnalyticsTracker();
      final voice = InMemoryVoiceInterviewRepository();
      final capture = InMemoryVoiceCaptureRepository();

      await tester.pumpCandidateApp(
        candidateSessionRepository: InMemoryCandidateSessionRepository(
          session: const CandidateSession(
            candidateId: 'voice-candidate',
            isAuthenticated: true,
          ),
        ),
        candidateOnboardingRepository: InMemoryCandidateOnboardingRepository(
          initialDraft: const CandidateOnboardingDraft(
            currentStep: 10,
            isCompleted: true,
          ),
        ),
        analyticsTracker: analytics,
        voiceInterviewRepository: voice,
        voiceCaptureRepository: capture,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Start voice practice'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Start voice practice'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Allow recording for this practice session'));
      await tester.tap(find.text('Allow transcription and transcript review'));
      await tester.tap(find.text('Allow structured coaching evaluation'));
      await tester.tap(find.text('Continue to microphone check'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow microphone and continue'));
      await tester.pumpAndSettle();

      const transcripts = [
        'First I recount and verify the stock then record both values and report the exception.',
        'First I check the SLA and safety risk then prioritise and inform the supervisor.',
        'I document the facts explain the risk and escalate clearly to my supervisor.',
      ];
      for (var index = 0; index < transcripts.length; index++) {
        await tester.tap(find.text('Start recording'));
        await tester.pumpAndSettle();
        expect(find.text('Recording…'), findsOneWidget);
        await tester.tap(find.text('Stop and review transcript'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), transcripts[index]);
        final label = index == transcripts.length - 1
            ? 'Finish and view feedback'
            : 'Save transcript and continue';
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      expect(find.text('Local coaching estimate'), findsOneWidget);
      expect(find.textContaining('Development coaching only'), findsOneWidget);
      expect(voice.state.answers, hasLength(3));
      expect(voice.state.evaluation, isNotNull);
      expect(voice.state.pendingUploadCount, 3);

      await tester.scrollUntilVisible(
        find.text('Request human review'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -160));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request human review'));
      await tester.pumpAndSettle();
      expect(voice.state.humanReviewRequested, isTrue);
      expect(
        analytics.events.map((event) => event.name),
        containsAll([
          'voice_consent_granted',
          'voice_turn_recorded',
          'voice_feedback_ready',
          'voice_human_review_requested',
        ]),
      );
    },
  );
}
