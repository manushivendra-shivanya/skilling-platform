import '../../../core/errors/result.dart';
import 'micro_lesson_assessment_attempt.dart';
import 'micro_lesson_clip.dart';

/// Retry policy for micro-lesson assessments: at most 3 recorded attempts
/// per clip per candidate. Every attempt up to the cap is recorded and
/// generates its own evidence (right or wrong -- an honest record, not
/// just successes); [MicroLessonAssessmentRepository.recordAttempt]
/// returns a [ValidationFailure]-backed failure once the cap is reached,
/// rather than silently discarding the extra attempt or overwriting an
/// earlier one.
const maxAssessmentAttemptsPerClip = 3;

abstract interface class MicroLessonAssessmentRepository {
  Future<Result<List<MicroLessonAssessmentAttempt>>> listAttempts(
    String candidateId,
  );

  /// Records an assessment submission for [clip], enforcing
  /// [maxAssessmentAttemptsPerClip]. Snapshots the clip's title and
  /// competency tags onto the attempt itself (see
  /// [MicroLessonAssessmentAttempt]) -- callers don't need to re-supply
  /// them separately.
  Future<Result<MicroLessonAssessmentAttempt>> recordAttempt({
    required String candidateId,
    required MicroLessonClip clip,
    required String selectedAnswerId,
  });
}
