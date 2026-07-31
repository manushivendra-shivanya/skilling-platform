import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/career_passport/data/wms_career_passport_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_simulation_controller.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const candidateId = 'candidate-1';
  final fixedTime = DateTime.utc(2026, 8, 1, 9);

  test(
    'loads evidence only from completed attempts on known WMS missions',
    () async {
      final store = InMemorySecureKeyValueStore();
      final attempts = LocalSimulationAttemptRepository(
        store,
        clock: () => fixedTime,
      );
      final repository = WmsCareerPassportRepository(
        attemptRepository: attempts,
      );

      final inProgress = await attempts.createAttempt(
        candidateId: candidateId,
        missionId: WorkplaceSimulationController.missionId,
        missionVersion: '1.0.0',
        scenarioSeed: 1,
      );
      // Left as notStarted -- should be excluded.
      expect(inProgress.state, MissionState.notStarted);

      final completed = await attempts.createAttempt(
        candidateId: candidateId,
        missionId: WorkplaceSimulationController.putAwayMissionId,
        missionVersion: '1.0.0',
        scenarioSeed: 2,
      );
      await attempts.saveAttempt(
        completed.copyWith(state: MissionState.completed),
      );
      await attempts.saveResult(candidateId, _result(completed));

      final result = await repository.loadEvidence(candidateId);

      result.when(
        success: (evidence) {
          expect(evidence.single.id, '${completed.id}-put-away-accuracy');
        },
        failure: (failure) => fail('expected success, got $failure'),
      );
    },
  );

  test('local-only repository cannot manage sharing', () async {
    final store = InMemorySecureKeyValueStore();
    final attempts = LocalSimulationAttemptRepository(
      store,
      clock: () => fixedTime,
    );
    final repository = WmsCareerPassportRepository(attemptRepository: attempts);

    expect(repository.canManageSharing, isFalse);
    final isShareable = await repository.isShareable(candidateId);
    isShareable.when(
      success: (value) => expect(value, isFalse),
      failure: (failure) => fail('expected success, got $failure'),
    );
    final setResult = await repository.setShareable(candidateId, true);
    expect(setResult, isA<Object>());
    setResult.when(
      success: (_) => fail('expected failure without a Supabase client'),
      failure: (failure) =>
          expect(failure.message, 'Sharing requires an account connection.'),
    );
  });
}

SimulationResult _result(SimulationAttempt attempt) => SimulationResult(
  attemptId: attempt.id,
  missionId: attempt.missionId,
  missionVersion: attempt.missionVersion,
  scenarioSeed: attempt.scenarioSeed,
  status: MissionStatus.passed,
  overallScore: 90,
  categoryScores: const {'put-away': 90},
  competencyScores: const [
    CompetencyScore(competencyId: 'put-away-accuracy', score: 90),
  ],
  mandatoryTasksCompleted: true,
  criticalErrors: const [],
  correctActions: const [],
  missedIssues: const [],
  evidence: [
    EvidenceRecord(
      id: '${attempt.id}-put-away-accuracy',
      candidateId: attempt.candidateId,
      attemptId: attempt.id,
      missionId: attempt.missionId,
      missionVersion: attempt.missionVersion,
      scenarioSeed: attempt.scenarioSeed,
      competencyId: 'put-away-accuracy',
      score: 90,
      evidenceType: EvidenceType.simulationObservation,
      title: 'Observed Put Away Accuracy',
      description: 'Generated from the append-only action trail.',
      issuedAt: DateTime.utc(2026, 8, 1, 9, 20),
      verificationStatus: EvidenceVerificationStatus.systemObserved,
    ),
  ],
  recommendedRemediationIds: const [],
  completedAt: DateTime.utc(2026, 8, 1, 9, 20),
);
