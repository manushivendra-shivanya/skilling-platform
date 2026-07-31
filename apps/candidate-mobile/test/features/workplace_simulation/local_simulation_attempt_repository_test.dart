import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const candidateId = 'candidate-1';
  const missionId = 'mission-1';
  final fixedTime = DateTime.utc(2026, 8, 1, 9);

  test('listResults is empty when nothing has been attempted', () async {
    final repository = LocalSimulationAttemptRepository(
      InMemorySecureKeyValueStore(),
      clock: () => fixedTime,
    );

    expect(await repository.listResults(candidateId, missionId), isEmpty);
  });

  test('listResults excludes attempts that never had a result saved', () async {
    final repository = LocalSimulationAttemptRepository(
      InMemorySecureKeyValueStore(),
      clock: () => fixedTime,
    );
    await repository.createAttempt(
      candidateId: candidateId,
      missionId: missionId,
      missionVersion: '1.0.0',
      scenarioSeed: 1,
    );

    expect(await repository.listResults(candidateId, missionId), isEmpty);
  });

  test(
    'listResults returns every saved result newest-first, across retakes',
    () async {
      final repository = LocalSimulationAttemptRepository(
        InMemorySecureKeyValueStore(),
        clock: () => fixedTime,
      );

      final first = await repository.createAttempt(
        candidateId: candidateId,
        missionId: missionId,
        missionVersion: '1.0.0',
        scenarioSeed: 1,
      );
      await repository.saveResult(candidateId, _result(first));
      await repository.clearActiveAttempt(candidateId, missionId);

      final retake = await repository.createAttempt(
        candidateId: candidateId,
        missionId: missionId,
        missionVersion: '1.0.0',
        scenarioSeed: 2,
      );
      await repository.saveResult(candidateId, _result(retake));

      final results = await repository.listResults(candidateId, missionId);

      expect(results.map((r) => r.attemptId), [retake.id, first.id]);
    },
  );
}

SimulationResult _result(SimulationAttempt attempt) => SimulationResult(
  attemptId: attempt.id,
  missionId: attempt.missionId,
  missionVersion: attempt.missionVersion,
  scenarioSeed: attempt.scenarioSeed,
  status: MissionStatus.passed,
  overallScore: 80,
  categoryScores: const {'receiving': 80},
  competencyScores: const [
    CompetencyScore(competencyId: 'receiving-accuracy', score: 80),
  ],
  mandatoryTasksCompleted: true,
  criticalErrors: const [],
  correctActions: const [],
  missedIssues: const [],
  evidence: const [],
  recommendedRemediationIds: const [],
  completedAt: DateTime.utc(2026, 8, 1, 9, 20),
);
