import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/micro_lessons/data/secure_micro_lesson_assessment_repository.dart';
import 'package:candidate_mobile/features/micro_lessons/domain/micro_lesson_clip.dart';
import 'package:candidate_mobile/features/micro_lessons/domain/micro_lesson_clip_repository.dart';
import 'package:candidate_mobile/features/onboarding/data/secure_candidate_onboarding_repository.dart';
import 'package:candidate_mobile/features/onboarding/domain/candidate_onboarding_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class _FakeMicroLessonClipRepository implements MicroLessonClipRepository {
  _FakeMicroLessonClipRepository(this._result);

  final Result<List<MicroLessonClip>> _result;

  @override
  Future<Result<List<MicroLessonClip>>> loadClips() async => _result;
}

void main() {
  late InMemoryCandidateSessionRepository sessions;
  late InMemoryCandidateOnboardingRepository onboarding;

  setUp(() {
    sessions = InMemoryCandidateSessionRepository(
      session: const CandidateSession(
        candidateId: 'dev-candidate-3210',
        isAuthenticated: true,
      ),
    );
    onboarding = InMemoryCandidateOnboardingRepository(
      initialDraft: _completedDraft(),
    );
  });

  testWidgets(
    'shows clips grouped by domain with the not-employer-evidence disclaimer',
    (tester) async {
      // The merged Learn/Practise tab adds a sub-tab bar above the content,
      // which the default 800x600 test surface no longer has room for.
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        candidateOnboardingRepository: onboarding,
        microLessonClipRepository: _FakeMicroLessonClipRepository(
          Success([_receivingClip(), _inspectionClip()]),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Learn'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Warehouse process clips'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Warehouse process clips'), findsOneWidget);
      expect(find.text('Receiving'), findsOneWidget);
      expect(find.text('Inspection'), findsOneWidget);
      expect(find.text('Frozen receiving check'), findsOneWidget);
      expect(find.text('FNV quality check'), findsOneWidget);
      expect(
        find.text('Practice feedback only — not employer evidence yet.'),
        findsWidgets,
      );
      // No video bundled for either fixture clip -- should read as a real,
      // plain state rather than an error.
      expect(find.textContaining('Video not yet available'), findsNWidgets(2));
    },
  );

  testWidgets('opens a clip and shows local right/wrong practice feedback', (
    tester,
  ) async {
    // The clip detail screen's video area is a 9:16 box at full viewport
    // width -- at the default 800x600 test surface that alone is ~1420px
    // tall, well past the window. A taller surface avoids needing to
    // scroll after every single assertion below the fold.
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
      microLessonClipRepository: _FakeMicroLessonClipRepository(
        Success([_receivingClip()]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Frozen receiving check'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Frozen receiving check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frozen receiving check'));
    await tester.pumpAndSettle();

    expect(
      find.text('Warehouse Operations Associate • Receiving Dock'),
      findsOneWidget,
    );
    expect(find.text('Check the pallet temperature.'), findsOneWidget);
    expect(find.text('Escalate before accepting.'), findsOneWidget);
    expect(find.text('Cold-chain basics.'), findsOneWidget);
    expect(find.text('What should you do first?'), findsOneWidget);

    await tester.tap(find.text('Accept the delivery'));
    await tester.pumpAndSettle();
    expect(
      find.text('Not safe -- always verify temperature first.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Record the temperature reading'));
    await tester.pumpAndSettle();
    expect(
      find.text('Correct -- this preserves the audit trail.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'submits an assessment attempt, records it, and counts down remaining attempts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final assessments = SecureMicroLessonAssessmentRepository(
        InMemorySecureKeyValueStore(),
      );
      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        candidateOnboardingRepository: onboarding,
        microLessonClipRepository: _FakeMicroLessonClipRepository(
          Success([_receivingClip()]),
        ),
        microLessonAssessmentRepository: assessments,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Learn'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Frozen receiving check'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Frozen receiving check'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Frozen receiving check'));
      await tester.pumpAndSettle();

      expect(find.textContaining('3 of 3 attempts remaining'), findsOneWidget);

      await tester.tap(find.text('Record the temperature reading'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Submit for Career Passport evidence'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.text('Submit for Career Passport evidence'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit for Career Passport evidence'));
      await tester.pumpAndSettle();

      expect(find.text('Recorded -- correct answer.'), findsOneWidget);
      expect(find.textContaining('2 of 3 attempts remaining'), findsOneWidget);

      final attempts = await assessments.listAttempts('dev-candidate-3210');
      attempts.when(
        success: (value) {
          expect(value, hasLength(1));
          expect(value.single.isCorrect, isTrue);
          expect(value.single.competencyTags, ['cold_chain_receiving_check']);
        },
        failure: (failure) => fail('expected success, got $failure'),
      );
    },
  );

  testWidgets('shows an empty state when the catalogue has no clips', (
    tester,
  ) async {
    // The merged Learn/Practise tab adds a sub-tab bar above the content,
    // which the default 800x600 test surface no longer has room for.
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpCandidateApp(
      candidateSessionRepository: sessions,
      candidateOnboardingRepository: onboarding,
      microLessonClipRepository: _FakeMicroLessonClipRepository(
        const Success([]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('No clips yet'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('No clips yet'), findsOneWidget);
  });

  testWidgets(
    'shows a recoverable error state when the catalogue fails to load',
    (tester) async {
      // The merged Learn/Practise tab adds a sub-tab bar above the content,
      // which the default 800x600 test surface no longer has room for.
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpCandidateApp(
        candidateSessionRepository: sessions,
        candidateOnboardingRepository: onboarding,
        microLessonClipRepository: _FakeMicroLessonClipRepository(
          const ResultFailure(NetworkFailure('offline')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Learn'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Clips could not be loaded'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Clips could not be loaded'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    },
  );
}

MicroLessonClip _receivingClip() {
  return MicroLessonClip(
    id: 'clip_receiving_frozen_001',
    title: 'Frozen receiving check',
    module: MicroLessonModule.inward,
    sequenceNumber: 1,
    domain: MicroLessonDomain.receiving,
    role: 'Warehouse Operations Associate',
    processArea: 'Receiving Dock',
    temperatureZone: TemperatureZone.frozen,
    durationSeconds: 10,
    videoUrl: null,
    cloudflareVideoPath: null,
    fallbackVideoUrl: null,
    thumbnailUrl: null,
    transcript: 'Transcript',
    description: 'A frozen pallet arrives at the dock.',
    expectedObservation: 'Check the pallet temperature.',
    expectedDecision: 'Escalate before accepting.',
    competencyTags: const ['cold_chain_receiving_check'],
    lessonContent: 'Cold-chain basics.',
    assessmentQuestion: 'What should you do first?',
    answerOptions: const [
      ClipAnswerOption(
        id: 'accept',
        label: 'Accept the delivery',
        feedback: 'Not safe -- always verify temperature first.',
      ),
      ClipAnswerOption(
        id: 'record',
        label: 'Record the temperature reading',
        feedback: 'Correct -- this preserves the audit trail.',
      ),
    ],
    correctAnswerId: 'record',
    scoringRules: const ClipScoringRules(
      maxPoints: 10,
      correctAnswerPoints: 10,
      evidenceSource: 'systemObserved',
      technicalFailuresScoreable: false,
    ),
    auditEvents: const [
      ClipAuditEventDefinition(
        eventType: 'clipAnswerSubmitted',
        when: 'onAnswerSubmit',
      ),
    ],
  );
}

MicroLessonClip _inspectionClip() {
  return MicroLessonClip(
    id: 'clip_inspection_fnv_001',
    title: 'FNV quality check',
    module: MicroLessonModule.inward,
    sequenceNumber: 5,
    domain: MicroLessonDomain.inspection,
    role: 'Quality Associate',
    processArea: 'FNV Inspection Table',
    temperatureZone: TemperatureZone.fnv,
    durationSeconds: 10,
    videoUrl: null,
    cloudflareVideoPath: null,
    fallbackVideoUrl: null,
    thumbnailUrl: null,
    transcript: 'Transcript',
    description: 'Inspect the produce.',
    expectedObservation: 'Inspect the produce.',
    expectedDecision: 'Segregate damaged stock.',
    competencyTags: const ['quality_segregation'],
    lessonContent: 'Quality basics.',
    assessmentQuestion: 'What do you do with damaged produce?',
    answerOptions: const [
      ClipAnswerOption(
        id: 'keep',
        label: 'Keep it with the rest',
        feedback: 'Wrong.',
      ),
      ClipAnswerOption(
        id: 'segregate',
        label: 'Segregate it',
        feedback: 'Correct.',
      ),
    ],
    correctAnswerId: 'segregate',
    scoringRules: const ClipScoringRules(
      maxPoints: 10,
      correctAnswerPoints: 10,
      evidenceSource: 'systemObserved',
      technicalFailuresScoreable: false,
    ),
    auditEvents: const [],
  );
}

CandidateOnboardingDraft _completedDraft() {
  final acceptedAt = DateTime.utc(2026, 7, 27);
  return CandidateOnboardingDraft(
    currentStep: 10,
    goal: CandidateGoal.findJob,
    fullName: 'Asha Kumari',
    city: 'Lucknow',
    state: 'Uttar Pradesh',
    pinCode: '226001',
    education: EducationLevel.twelfthPass,
    experience: ExperienceLevel.fresher,
    preferredRoles: const {LogisticsRole.warehouseAssociate},
    consents: {
      OnboardingConsentVersions.termsPurpose: ConsentAcceptance(
        purpose: OnboardingConsentVersions.termsPurpose,
        version: OnboardingConsentVersions.termsVersion,
        acceptedAt: acceptedAt,
      ),
      OnboardingConsentVersions.privacyPurpose: ConsentAcceptance(
        purpose: OnboardingConsentVersions.privacyPurpose,
        version: OnboardingConsentVersions.privacyVersion,
        acceptedAt: acceptedAt,
      ),
    },
    isCompleted: true,
  );
}
