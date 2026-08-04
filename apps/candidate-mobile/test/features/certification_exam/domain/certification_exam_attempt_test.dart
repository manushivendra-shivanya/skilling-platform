import 'package:candidate_mobile/features/certification_exam/domain/certification_exam_attempt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final startedAt = DateTime.utc(2026, 8, 5, 9);
  final submittedAt = DateTime.utc(2026, 8, 5, 9, 12);

  CertificationExamAttempt attemptWith(List<QuestionResponse> responses) {
    return CertificationExamAttempt(
      id: 'attempt-1',
      candidateId: 'candidate-1',
      examId: 'exam-1',
      examVersion: '1',
      responses: responses,
      startedAt: startedAt,
      submittedAt: submittedAt,
    );
  }

  QuestionResponse response({required String id, required bool correct}) =>
      QuestionResponse(
        questionId: id,
        competencyId: 'tag-$id',
        selectedOptionId: correct ? 'correct' : 'wrong',
        correctOptionId: 'correct',
      );

  test('scores 100% when every response is correct', () {
    final attempt = attemptWith([
      response(id: 'q1', correct: true),
      response(id: 'q2', correct: true),
    ]);
    expect(attempt.correctCount, 2);
    expect(attempt.scorePercent, 100);
    expect(attempt.passed(70), isTrue);
  });

  test('scores partial credit and rounds to the nearest percent', () {
    final attempt = attemptWith([
      response(id: 'q1', correct: true),
      response(id: 'q2', correct: true),
      response(id: 'q3', correct: false),
    ]);
    expect(attempt.correctCount, 2);
    expect(attempt.scorePercent, 67); // 2/3 = 66.67, rounds to 67
  });

  test('passed() compares against the given threshold', () {
    final attempt = attemptWith([
      response(id: 'q1', correct: true),
      response(id: 'q2', correct: false),
    ]);
    expect(attempt.scorePercent, 50);
    expect(attempt.passed(50), isTrue);
    expect(attempt.passed(70), isFalse);
  });

  test('timeTaken is the gap between startedAt and submittedAt', () {
    final attempt = attemptWith([response(id: 'q1', correct: true)]);
    expect(attempt.timeTaken, const Duration(minutes: 12));
  });

  test('round-trips through JSON', () {
    final attempt = attemptWith([
      response(id: 'q1', correct: true),
      response(id: 'q2', correct: false),
    ]);
    final decoded = CertificationExamAttempt.fromJson(attempt.toJson());
    expect(decoded.id, attempt.id);
    expect(decoded.examId, attempt.examId);
    expect(decoded.responses.length, attempt.responses.length);
    expect(decoded.scorePercent, attempt.scorePercent);
    expect(decoded.startedAt, attempt.startedAt);
    expect(decoded.submittedAt, attempt.submittedAt);
  });
}
