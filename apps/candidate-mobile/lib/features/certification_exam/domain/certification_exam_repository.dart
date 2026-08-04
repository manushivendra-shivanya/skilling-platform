import '../../../core/errors/result.dart';
import 'certification_exam.dart';
import 'certification_exam_attempt.dart';

abstract interface class CertificationExamRepository {
  Future<Result<CertificationExam>> loadExam();
}

/// Advisory-only retake cooldown after a failed attempt: shown to the
/// candidate as "you can retake in X hours", not enforced by
/// [CertificationExamAttemptRepository.recordAttempt]. Attempts are stored
/// on-device only (same posture as `MicroLessonAssessmentRepository` today),
/// so there's no real anti-cheat backing either feature -- hard-enforcing a
/// cooldown here would be inconsistent rigor for no real security benefit.
/// Multiple attempts are still handled correctly: Career Passport's
/// freshness rules (`deriveCareerPassportEntries`) let the newest evidence
/// supersede older evidence for the same competency.
const certificationExamRetakeCooldown = Duration(hours: 24);

abstract interface class CertificationExamAttemptRepository {
  Future<Result<List<CertificationExamAttempt>>> listAttempts(
    String candidateId,
    String examId,
  );

  /// Records a completed exam sitting. [responses] must be non-empty and
  /// cover every question in [exam] exactly once.
  Future<Result<CertificationExamAttempt>> recordAttempt({
    required String candidateId,
    required CertificationExam exam,
    required List<QuestionResponse> responses,
    required DateTime startedAt,
    required DateTime submittedAt,
  });
}
