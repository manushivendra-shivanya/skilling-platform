import 'certification_exam.dart';

class CertificationExamValidationError {
  const CertificationExamValidationError(this.questionId, this.message);

  final String questionId;
  final String message;

  @override
  String toString() => '$questionId: $message';
}

List<CertificationExamValidationError> validateCertificationExamQuestion(
  CertificationExamQuestion question,
) {
  final errors = <CertificationExamValidationError>[];
  void add(String message) {
    errors.add(CertificationExamValidationError(question.id, message));
  }

  if (question.id.trim().isEmpty) {
    add('id is required');
  }
  if (question.competencyId.trim().isEmpty) {
    add('competencyId is required');
  }
  if (question.prompt.trim().isEmpty) {
    add('prompt is required');
  }
  if (question.options.length < 2) {
    add('at least two options required');
  }
  final optionIds = <String>{};
  for (final option in question.options) {
    if (!optionIds.add(option.id)) {
      add('duplicate option id "${option.id}"');
    }
  }
  if (!question.options.any(
    (option) => option.id == question.correctOptionId,
  )) {
    add('correctOptionId must match an option id');
  }

  return errors;
}

List<CertificationExamValidationError> validateCertificationExam(
  CertificationExam exam,
) {
  final errors = <CertificationExamValidationError>[];
  void add(String message) {
    errors.add(CertificationExamValidationError(exam.id, message));
  }

  if (exam.id.trim().isEmpty) {
    add('id is required');
  }
  if (exam.title.trim().isEmpty) {
    add('title is required');
  }
  if (exam.questions.isEmpty) {
    add('at least one question is required');
  }
  if (exam.passThresholdPercent < 0 || exam.passThresholdPercent > 100) {
    add('passThresholdPercent must be between 0 and 100');
  }
  if (exam.timeLimit <= Duration.zero) {
    add('timeLimit must be positive');
  }

  final questionIds = <String>{};
  for (final question in exam.questions) {
    if (!questionIds.add(question.id)) {
      errors.add(
        CertificationExamValidationError(question.id, 'duplicate question id'),
      );
    }
    errors.addAll(validateCertificationExamQuestion(question));
  }
  return errors;
}
