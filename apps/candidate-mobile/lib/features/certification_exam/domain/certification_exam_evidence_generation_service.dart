import '../../workplace_simulation/domain/simulation_enums.dart';
import '../../workplace_simulation/domain/simulation_runtime.dart';
import 'certification_exam.dart';
import 'certification_exam_attempt.dart';

/// Converts a completed [CertificationExamAttempt] into [EvidenceRecord]s
/// for the Career Passport -- but, unlike
/// `MicroLessonEvidenceGenerationService` (which records every attempt,
/// right or wrong), only when the attempt actually passes the exam's
/// [CertificationExam.passThresholdPercent]. A certification is a holistic
/// pass/fail signal, not a per-question one: a failed attempt earns no
/// partial credit, and a passed attempt earns evidence for every
/// competency the exam covers, scored at the overall exam percentage
/// rather than per-question.
class CertificationExamEvidenceGenerationService {
  const CertificationExamEvidenceGenerationService();

  List<EvidenceRecord> generate(
    CertificationExamAttempt attempt,
    CertificationExam exam,
  ) {
    if (!attempt.passed(exam.passThresholdPercent)) return const [];

    final competencyIds = {
      for (final response in attempt.responses) response.competencyId,
    };
    return [
      for (final competencyId in competencyIds)
        EvidenceRecord(
          id: '${attempt.id}-$competencyId',
          candidateId: attempt.candidateId,
          attemptId: attempt.id,
          missionId: attempt.examId,
          missionVersion: attempt.examVersion,
          scenarioSeed: 0,
          competencyId: competencyId,
          score: attempt.scorePercent,
          evidenceType: EvidenceType.certificationExam,
          title: 'Certified: ${_displayName(competencyId)}',
          description:
              'Passed the "${exam.title}" certification exam with a score '
              'of ${attempt.scorePercent}%.',
          issuedAt: attempt.submittedAt,
          verificationStatus: EvidenceVerificationStatus.systemObserved,
        ),
    ];
  }

  String _displayName(String value) => value
      .split(RegExp('[-_]'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
