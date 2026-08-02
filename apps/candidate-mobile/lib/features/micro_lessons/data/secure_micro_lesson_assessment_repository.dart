import 'dart:convert';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/storage/secure_key_value_store.dart';
import '../domain/micro_lesson_assessment_attempt.dart';
import '../domain/micro_lesson_assessment_repository.dart';
import '../domain/micro_lesson_clip.dart';

class SecureMicroLessonAssessmentRepository
    implements MicroLessonAssessmentRepository {
  SecureMicroLessonAssessmentRepository(this._store);

  static const _keyPrefix = 'micro_lessons.assessment_attempts.v1.';

  final SecureKeyValueStore _store;

  @override
  Future<Result<List<MicroLessonAssessmentAttempt>>> listAttempts(
    String candidateId,
  ) async {
    try {
      return Success(await _readAll(candidateId));
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Your assessment history could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<MicroLessonAssessmentAttempt>> recordAttempt({
    required String candidateId,
    required MicroLessonClip clip,
    required String selectedAnswerId,
  }) async {
    try {
      final existing = await _readAll(candidateId);
      final attemptsForClip = existing
          .where((attempt) => attempt.clipId == clip.id)
          .length;
      if (attemptsForClip >= maxAssessmentAttemptsPerClip) {
        return ResultFailure(
          ValidationFailure(
            'You have used all $maxAssessmentAttemptsPerClip attempts for '
            'this clip.',
          ),
        );
      }

      final now = DateTime.now().toUtc();
      final attemptId = '${clip.id}-${now.microsecondsSinceEpoch}';
      final isCorrect = selectedAnswerId == clip.correctAnswerId;
      final attempt = MicroLessonAssessmentAttempt(
        id: attemptId,
        candidateId: candidateId,
        clipId: clip.id,
        clipTitle: clip.title,
        competencyTags: clip.competencyTags,
        selectedAnswerId: selectedAnswerId,
        correctAnswerId: clip.correctAnswerId,
        submittedAt: now,
        auditEvents: [
          for (final definition in clip.auditEvents)
            RecordedAuditEvent(
              eventType: definition.eventType,
              occurredAt: now,
              payload: {
                ...definition.payload,
                'selectedAnswerId': selectedAnswerId,
                'isCorrect': isCorrect,
                'attemptNumber': attemptsForClip + 1,
              },
            ),
        ],
      );

      await _store.write(
        _keyFor(candidateId),
        jsonEncode([...existing, attempt].map((a) => a.toJson()).toList()),
      );
      return Success(attempt);
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Your assessment attempt could not be saved on this device.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<List<MicroLessonAssessmentAttempt>> _readAll(
    String candidateId,
  ) async {
    final encoded = await _store.read(_keyFor(candidateId));
    if (encoded == null) return const [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('Invalid micro-lesson assessment history');
    }
    return decoded
        .map(
          (item) => MicroLessonAssessmentAttempt.fromJson(
            item as Map<String, Object?>,
          ),
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
