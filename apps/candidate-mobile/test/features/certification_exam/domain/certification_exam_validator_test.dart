import 'package:candidate_mobile/features/certification_exam/domain/certification_exam.dart';
import 'package:candidate_mobile/features/certification_exam/domain/certification_exam_validator.dart';
import 'package:flutter_test/flutter_test.dart';

CertificationExamQuestion _validQuestion({String id = 'q1'}) {
  return CertificationExamQuestion(
    id: id,
    competencyId: 'tag-a',
    prompt: 'Prompt?',
    options: const [
      ExamAnswerOption(id: 'correct', label: 'Correct', feedback: 'Good'),
      ExamAnswerOption(id: 'wrong', label: 'Wrong', feedback: 'Bad'),
    ],
    correctOptionId: 'correct',
  );
}

CertificationExam _validExam({List<CertificationExamQuestion>? questions}) {
  return CertificationExam(
    id: 'exam-1',
    title: 'Warehouse Operations Certification',
    version: '1',
    description: 'Description',
    timeLimit: const Duration(minutes: 15),
    passThresholdPercent: 70,
    questions: questions ?? [_validQuestion()],
  );
}

void main() {
  test('a well-formed exam has no validation errors', () {
    expect(validateCertificationExam(_validExam()), isEmpty);
  });

  test('rejects an exam with no questions', () {
    final errors = validateCertificationExam(_validExam(questions: const []));
    expect(
      errors.map((e) => e.message),
      contains('at least one question is required'),
    );
  });

  test('rejects a pass threshold outside 0-100', () {
    final exam = CertificationExam(
      id: 'exam-1',
      title: 'Title',
      version: '1',
      description: 'Description',
      timeLimit: const Duration(minutes: 15),
      passThresholdPercent: 150,
      questions: [_validQuestion()],
    );
    final errors = validateCertificationExam(exam);
    expect(
      errors.map((e) => e.message),
      contains('passThresholdPercent must be between 0 and 100'),
    );
  });

  test('rejects a non-positive time limit', () {
    final exam = CertificationExam(
      id: 'exam-1',
      title: 'Title',
      version: '1',
      description: 'Description',
      timeLimit: Duration.zero,
      passThresholdPercent: 70,
      questions: [_validQuestion()],
    );
    final errors = validateCertificationExam(exam);
    expect(
      errors.map((e) => e.message),
      contains('timeLimit must be positive'),
    );
  });

  test('rejects duplicate question ids', () {
    final exam = _validExam(questions: [_validQuestion(), _validQuestion()]);
    final errors = validateCertificationExam(exam);
    expect(errors.map((e) => e.message), contains('duplicate question id'));
  });

  test('rejects a question with fewer than two options', () {
    final question = CertificationExamQuestion(
      id: 'q1',
      competencyId: 'tag-a',
      prompt: 'Prompt?',
      options: const [
        ExamAnswerOption(id: 'correct', label: 'Correct', feedback: 'Good'),
      ],
      correctOptionId: 'correct',
    );
    final errors = validateCertificationExamQuestion(question);
    expect(
      errors.map((e) => e.message),
      contains('at least two options required'),
    );
  });

  test('rejects a correctOptionId that does not match any option', () {
    final question = CertificationExamQuestion(
      id: 'q1',
      competencyId: 'tag-a',
      prompt: 'Prompt?',
      options: const [
        ExamAnswerOption(id: 'a', label: 'A', feedback: 'Feedback'),
        ExamAnswerOption(id: 'b', label: 'B', feedback: 'Feedback'),
      ],
      correctOptionId: 'missing',
    );
    final errors = validateCertificationExamQuestion(question);
    expect(
      errors.map((e) => e.message),
      contains('correctOptionId must match an option id'),
    );
  });

  test('rejects duplicate option ids within a question', () {
    final question = CertificationExamQuestion(
      id: 'q1',
      competencyId: 'tag-a',
      prompt: 'Prompt?',
      options: const [
        ExamAnswerOption(id: 'a', label: 'A', feedback: 'Feedback'),
        ExamAnswerOption(id: 'a', label: 'A again', feedback: 'Feedback'),
      ],
      correctOptionId: 'a',
    );
    final errors = validateCertificationExamQuestion(question);
    expect(errors.map((e) => e.message), contains('duplicate option id "a"'));
  });
}
