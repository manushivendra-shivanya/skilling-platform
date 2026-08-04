import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/certification_exam/data/secure_certification_exam_attempt_repository.dart';
import 'package:candidate_mobile/features/certification_exam/domain/certification_exam.dart';
import 'package:candidate_mobile/features/certification_exam/domain/certification_exam_attempt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const candidateId = 'candidate-1';
  final startedAt = DateTime.utc(2026, 8, 5, 9);
  final submittedAt = DateTime.utc(2026, 8, 5, 9, 12);

  test('records a completed attempt with all questions answered', () async {
    final repository = SecureCertificationExamAttemptRepository(
      InMemorySecureKeyValueStore(),
    );
    final result = await repository.recordAttempt(
      candidateId: candidateId,
      exam: _exam(),
      responses: const [
        QuestionResponse(
          questionId: 'q1',
          competencyId: 'tag-a',
          selectedOptionId: 'correct',
          correctOptionId: 'correct',
        ),
        QuestionResponse(
          questionId: 'q2',
          competencyId: 'tag-b',
          selectedOptionId: 'wrong',
          correctOptionId: 'correct',
        ),
      ],
      startedAt: startedAt,
      submittedAt: submittedAt,
    );

    result.when(
      success: (attempt) {
        expect(attempt.examId, 'exam-1');
        expect(attempt.correctCount, 1);
        expect(attempt.scorePercent, 50);
      },
      failure: (failure) => fail('expected success, got $failure'),
    );
  });

  test(
    'rejects an attempt missing a response for one of the exam questions',
    () async {
      final repository = SecureCertificationExamAttemptRepository(
        InMemorySecureKeyValueStore(),
      );
      final result = await repository.recordAttempt(
        candidateId: candidateId,
        exam: _exam(),
        responses: const [
          QuestionResponse(
            questionId: 'q1',
            competencyId: 'tag-a',
            selectedOptionId: 'correct',
            correctOptionId: 'correct',
          ),
        ],
        startedAt: startedAt,
        submittedAt: submittedAt,
      );

      result.when(
        success: (_) => fail('expected a rejected attempt'),
        failure: (failure) => expect(
          failure.message,
          contains('do not match this exam\'s questions'),
        ),
      );
    },
  );

  test(
    'rejects an attempt with an extra response for an unknown question',
    () async {
      final repository = SecureCertificationExamAttemptRepository(
        InMemorySecureKeyValueStore(),
      );
      final result = await repository.recordAttempt(
        candidateId: candidateId,
        exam: _exam(),
        responses: const [
          QuestionResponse(
            questionId: 'q1',
            competencyId: 'tag-a',
            selectedOptionId: 'correct',
            correctOptionId: 'correct',
          ),
          QuestionResponse(
            questionId: 'q2',
            competencyId: 'tag-b',
            selectedOptionId: 'correct',
            correctOptionId: 'correct',
          ),
          QuestionResponse(
            questionId: 'q3-does-not-exist',
            competencyId: 'tag-c',
            selectedOptionId: 'correct',
            correctOptionId: 'correct',
          ),
        ],
        startedAt: startedAt,
        submittedAt: submittedAt,
      );

      result.when(
        success: (_) => fail('expected a rejected attempt'),
        failure: (failure) => expect(
          failure.message,
          contains('do not match this exam\'s questions'),
        ),
      );
    },
  );

  test('rejects an empty response list', () async {
    final repository = SecureCertificationExamAttemptRepository(
      InMemorySecureKeyValueStore(),
    );
    final result = await repository.recordAttempt(
      candidateId: candidateId,
      exam: _exam(),
      responses: const [],
      startedAt: startedAt,
      submittedAt: submittedAt,
    );

    result.when(
      success: (_) => fail('expected a rejected attempt'),
      failure: (failure) =>
          expect(failure.message, contains('answered exactly once')),
    );
  });

  test('listAttempts filters to the requested examId', () async {
    final repository = SecureCertificationExamAttemptRepository(
      InMemorySecureKeyValueStore(),
    );
    await repository.recordAttempt(
      candidateId: candidateId,
      exam: _exam(),
      responses: const [
        QuestionResponse(
          questionId: 'q1',
          competencyId: 'tag-a',
          selectedOptionId: 'correct',
          correctOptionId: 'correct',
        ),
        QuestionResponse(
          questionId: 'q2',
          competencyId: 'tag-b',
          selectedOptionId: 'correct',
          correctOptionId: 'correct',
        ),
      ],
      startedAt: startedAt,
      submittedAt: submittedAt,
    );
    await repository.recordAttempt(
      candidateId: candidateId,
      exam: _exam(id: 'other-exam'),
      responses: const [
        QuestionResponse(
          questionId: 'q1',
          competencyId: 'tag-a',
          selectedOptionId: 'correct',
          correctOptionId: 'correct',
        ),
        QuestionResponse(
          questionId: 'q2',
          competencyId: 'tag-b',
          selectedOptionId: 'correct',
          correctOptionId: 'correct',
        ),
      ],
      startedAt: startedAt,
      submittedAt: submittedAt,
    );

    final result = await repository.listAttempts(candidateId, 'exam-1');

    result.when(
      success: (attempts) =>
          expect(attempts.every((a) => a.examId == 'exam-1'), isTrue),
      failure: (failure) => fail('expected success, got $failure'),
    );
  });
}

CertificationExam _exam({String id = 'exam-1'}) {
  return CertificationExam(
    id: id,
    title: 'Test Exam',
    version: '1',
    description: 'Description',
    timeLimit: const Duration(minutes: 10),
    passThresholdPercent: 70,
    questions: const [
      CertificationExamQuestion(
        id: 'q1',
        competencyId: 'tag-a',
        prompt: 'Prompt 1?',
        options: [
          ExamAnswerOption(id: 'correct', label: 'Correct', feedback: 'Good'),
          ExamAnswerOption(id: 'wrong', label: 'Wrong', feedback: 'Bad'),
        ],
        correctOptionId: 'correct',
      ),
      CertificationExamQuestion(
        id: 'q2',
        competencyId: 'tag-b',
        prompt: 'Prompt 2?',
        options: [
          ExamAnswerOption(id: 'correct', label: 'Correct', feedback: 'Good'),
          ExamAnswerOption(id: 'wrong', label: 'Wrong', feedback: 'Bad'),
        ],
        correctOptionId: 'correct',
      ),
    ],
  );
}
