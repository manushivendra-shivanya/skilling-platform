import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/micro_lessons/data/secure_micro_lesson_assessment_repository.dart';
import 'package:candidate_mobile/features/micro_lessons/domain/micro_lesson_assessment_repository.dart';
import 'package:candidate_mobile/features/micro_lessons/domain/micro_lesson_clip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const candidateId = 'candidate-1';

  test('records a correct attempt with a 100% score', () async {
    final repository = SecureMicroLessonAssessmentRepository(
      InMemorySecureKeyValueStore(),
    );
    final result = await repository.recordAttempt(
      candidateId: candidateId,
      clip: _clip(),
      selectedAnswerId: 'correct',
    );
    result.when(
      success: (attempt) {
        expect(attempt.isCorrect, isTrue);
        expect(attempt.scorePercent, 100);
        expect(attempt.clipId, 'clip-1');
        expect(attempt.competencyTags, ['tag-a', 'tag-b']);
      },
      failure: (failure) => fail('expected success, got $failure'),
    );
  });

  test('records an incorrect attempt with a 0% score', () async {
    final repository = SecureMicroLessonAssessmentRepository(
      InMemorySecureKeyValueStore(),
    );
    final result = await repository.recordAttempt(
      candidateId: candidateId,
      clip: _clip(),
      selectedAnswerId: 'wrong',
    );
    result.when(
      success: (attempt) {
        expect(attempt.isCorrect, isFalse);
        expect(attempt.scorePercent, 0);
      },
      failure: (failure) => fail('expected success, got $failure'),
    );
  });

  test(
    'records the clip\'s declared audit events, stamped with submission context',
    () async {
      final repository = SecureMicroLessonAssessmentRepository(
        InMemorySecureKeyValueStore(),
      );
      final result = await repository.recordAttempt(
        candidateId: candidateId,
        clip: _clip(),
        selectedAnswerId: 'wrong',
      );
      result.when(
        success: (attempt) {
          expect(attempt.auditEvents, hasLength(1));
          final event = attempt.auditEvents.single;
          expect(event.eventType, 'clipAnswerSubmitted');
          expect(event.payload['selectedAnswerId'], 'wrong');
          expect(event.payload['isCorrect'], isFalse);
          expect(event.payload['attemptNumber'], 1);
        },
        failure: (failure) => fail('expected success, got $failure'),
      );
    },
  );

  test(
    'enforces the retry policy: rejects a 4th attempt on the same clip',
    () async {
      final repository = SecureMicroLessonAssessmentRepository(
        InMemorySecureKeyValueStore(),
      );
      for (var i = 0; i < maxAssessmentAttemptsPerClip; i++) {
        final result = await repository.recordAttempt(
          candidateId: candidateId,
          clip: _clip(),
          selectedAnswerId: 'wrong',
        );
        result.when(
          success: (attempt) => expect(
            attempt.auditEvents.single.payload['attemptNumber'],
            i + 1,
          ),
          failure: (failure) => fail('expected success, got $failure'),
        );
      }

      final rejected = await repository.recordAttempt(
        candidateId: candidateId,
        clip: _clip(),
        selectedAnswerId: 'correct',
      );
      rejected.when(
        success: (_) => fail('expected the 4th attempt to be rejected'),
        failure: (failure) => expect(
          failure.message,
          contains('used all $maxAssessmentAttemptsPerClip attempts'),
        ),
      );

      final attempts = await repository.listAttempts(candidateId);
      attempts.when(
        success: (value) =>
            expect(value, hasLength(maxAssessmentAttemptsPerClip)),
        failure: (failure) => fail('expected success, got $failure'),
      );
    },
  );

  test('tracks retry limits independently per clip', () async {
    final repository = SecureMicroLessonAssessmentRepository(
      InMemorySecureKeyValueStore(),
    );
    for (var i = 0; i < maxAssessmentAttemptsPerClip; i++) {
      await repository.recordAttempt(
        candidateId: candidateId,
        clip: _clip(id: 'clip-1'),
        selectedAnswerId: 'wrong',
      );
    }
    final otherClipResult = await repository.recordAttempt(
      candidateId: candidateId,
      clip: _clip(id: 'clip-2'),
      selectedAnswerId: 'correct',
    );
    otherClipResult.when(
      success: (attempt) => expect(attempt.clipId, 'clip-2'),
      failure: (failure) => fail('expected success, got $failure'),
    );
  });
}

MicroLessonClip _clip({String id = 'clip-1'}) {
  return MicroLessonClip(
    id: id,
    title: 'Clip $id',
    module: MicroLessonModule.inward,
    sequenceNumber: 1,
    domain: MicroLessonDomain.receiving,
    role: 'Warehouse Operations Associate',
    processArea: 'Receiving Dock',
    temperatureZone: TemperatureZone.mixed,
    durationSeconds: 10,
    videoUrl: null,
    cloudflareVideoPath: null,
    fallbackVideoUrl: null,
    thumbnailUrl: null,
    transcript: 'Transcript',
    description: 'Description',
    expectedObservation: 'Observation',
    expectedDecision: 'Decision',
    competencyTags: const ['tag-a', 'tag-b'],
    lessonContent: 'Lesson',
    assessmentQuestion: 'Question?',
    answerOptions: const [
      ClipAnswerOption(id: 'correct', label: 'Correct', feedback: 'Good'),
      ClipAnswerOption(id: 'wrong', label: 'Wrong', feedback: 'Try again'),
    ],
    correctAnswerId: 'correct',
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
