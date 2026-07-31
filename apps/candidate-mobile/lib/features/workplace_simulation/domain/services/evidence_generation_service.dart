import '../simulation_content.dart';
import '../simulation_enums.dart';
import '../simulation_runtime.dart';

class EvidenceGenerationService {
  const EvidenceGenerationService();

  List<CompetencyScore> competencyScores(List<ActionOutcome> outcomes) {
    final earned = <String, double>{};
    final available = <String, double>{};
    for (final outcome in outcomes) {
      for (final impact in outcome.competencyImpacts) {
        earned.update(
          impact.competencyId,
          (value) => value + impact.scoreDelta,
          ifAbsent: () => impact.scoreDelta,
        );
        available.update(
          impact.competencyId,
          (value) => value + impact.maximumScore,
          ifAbsent: () => impact.maximumScore,
        );
      }
    }
    return [
      for (final entry in available.entries)
        CompetencyScore(
          competencyId: entry.key,
          score: entry.value == 0
              ? 0
              : ((earned[entry.key] ?? 0) / entry.value * 100).round().clamp(
                  0,
                  100,
                ),
        ),
    ];
  }

  List<EvidenceRecord> generate({
    required SimulationAttempt attempt,
    required MissionDefinition mission,
    required List<CompetencyScore> competencyScores,
    required DateTime issuedAt,
  }) => [
    for (final score in competencyScores)
      EvidenceRecord(
        id: '${attempt.id}-${score.competencyId}',
        candidateId: attempt.candidateId,
        attemptId: attempt.id,
        missionId: mission.id,
        missionVersion: mission.version,
        scenarioSeed: attempt.scenarioSeed,
        competencyId: score.competencyId,
        score: score.score,
        evidenceType: EvidenceType.simulationObservation,
        title: 'Observed ${_displayName(score.competencyId)}',
        description:
            'Generated from the append-only action trail for '
            '${mission.title}.',
        issuedAt: issuedAt,
        verificationStatus: EvidenceVerificationStatus.systemObserved,
      ),
  ];

  String _displayName(String value) => value
      .split('-')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
