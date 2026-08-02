import '../../workplace_simulation/domain/simulation_enums.dart';
import '../../workplace_simulation/domain/simulation_runtime.dart';
import 'micro_lesson_assessment_attempt.dart';

/// Converts a completed [MicroLessonAssessmentAttempt] into
/// [EvidenceRecord]s for the Career Passport -- one per competency tag on
/// the clip, mirroring how
/// `workplace_simulation/domain/services/evidence_generation_service.dart`
/// turns a simulation attempt into per-competency evidence. Every
/// completed attempt generates evidence, right or wrong: the freshness
/// rules in `career_passport/domain/career_passport.dart` already handle
/// marking the newest as active and older ones as superseded, so there's
/// no need to special-case which attempt "counts".
class MicroLessonEvidenceGenerationService {
  const MicroLessonEvidenceGenerationService();

  List<EvidenceRecord> generate(MicroLessonAssessmentAttempt attempt) => [
    for (final competencyId in attempt.competencyTags)
      EvidenceRecord(
        id: '${attempt.id}-$competencyId',
        candidateId: attempt.candidateId,
        attemptId: attempt.id,
        missionId: attempt.clipId,
        missionVersion: '1',
        scenarioSeed: 0,
        competencyId: competencyId,
        score: attempt.scorePercent,
        evidenceType: EvidenceType.microLessonAssessment,
        title: 'Observed ${_displayName(competencyId)}',
        description:
            'Generated from a completed micro-lesson assessment: '
            '"${attempt.clipTitle}".',
        issuedAt: attempt.submittedAt,
        verificationStatus: EvidenceVerificationStatus.systemObserved,
      ),
  ];

  // Unlike workplace-simulation competency ids (hyphen-separated), the
  // micro-lesson catalogue's competencyTags use underscores (e.g.
  // "cold_chain_receiving_check") -- split on both so this reads correctly
  // regardless of which convention a given tag follows.
  String _displayName(String value) => value
      .split(RegExp('[-_]'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
