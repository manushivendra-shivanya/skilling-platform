import 'dart:convert';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/storage/secure_key_value_store.dart';
import '../domain/certification_exam.dart';
import '../domain/certification_exam_attempt.dart';
import '../domain/certification_exam_repository.dart';

class SecureCertificationExamAttemptRepository
    implements CertificationExamAttemptRepository {
  SecureCertificationExamAttemptRepository(this._store);

  static const _keyPrefix = 'certification_exam.attempts.v1.';

  final SecureKeyValueStore _store;

  @override
  Future<Result<List<CertificationExamAttempt>>> listAttempts(
    String candidateId,
    String examId,
  ) async {
    try {
      final all = await _readAll(candidateId);
      return Success(
        all
            .where((attempt) => attempt.examId == examId)
            .toList(growable: false),
      );
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Your certification exam history could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<CertificationExamAttempt>> recordAttempt({
    required String candidateId,
    required CertificationExam exam,
    required List<QuestionResponse> responses,
    required DateTime startedAt,
    required DateTime submittedAt,
  }) async {
    final questionIds = exam.questions.map((q) => q.id).toSet();
    final responseIds = responses.map((r) => r.questionId).toSet();
    if (responses.isEmpty || responseIds.length != responses.length) {
      return const ResultFailure(
        ValidationFailure('Each exam question must be answered exactly once.'),
      );
    }
    if (!responseIds.containsAll(questionIds) ||
        !questionIds.containsAll(responseIds)) {
      return const ResultFailure(
        ValidationFailure(
          'The submitted answers do not match this exam\'s questions.',
        ),
      );
    }

    try {
      final existing = await _readAll(candidateId);
      final attemptId = '${exam.id}-${submittedAt.microsecondsSinceEpoch}';
      final attempt = CertificationExamAttempt(
        id: attemptId,
        candidateId: candidateId,
        examId: exam.id,
        examVersion: exam.version,
        responses: responses,
        startedAt: startedAt,
        submittedAt: submittedAt,
      );

      await _store.write(
        _keyFor(candidateId),
        jsonEncode([...existing, attempt].map((a) => a.toJson()).toList()),
      );
      return Success(attempt);
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Your exam attempt could not be saved on this device.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<List<CertificationExamAttempt>> _readAll(String candidateId) async {
    final encoded = await _store.read(_keyFor(candidateId));
    if (encoded == null) return const [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('Invalid certification exam history');
    }
    return decoded
        .map(
          (item) =>
              CertificationExamAttempt.fromJson(item as Map<String, Object?>),
        )
        .toList(growable: false);
  }

  String _keyFor(String candidateId) {
    final safeCandidateId = candidateId.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    return '$_keyPrefix$safeCandidateId';
  }
}
