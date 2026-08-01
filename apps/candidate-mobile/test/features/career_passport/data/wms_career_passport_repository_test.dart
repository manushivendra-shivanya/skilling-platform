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

  test('loads evidence only from attempts with a saved result', () async {
    final store = InMemorySecureKeyValueStore();
    final attempts = LocalSimulationAttemptRepository(
      store,
      clock: () => fixedTime,
    );
    final repository = WmsCareerPassportRepository(attemptRepository: attempts);

    final inProgress = await attempts.createAttempt(
      candidateId: candidateId,
      missionId: WorkplaceSimulationController.missionId,
      missionVersion: '1.0.0',
      scenarioSeed: 1,
    );
    // Never scored -- should be excluded.
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
    await attempts.saveResult(candidateId, _result(completed, score: 90));

    final result = await repository.loadEvidence(candidateId);

    result.when(
      success: (evidence) {
        expect(evidence.single.id, '${completed.id}-put-away-accuracy');
      },
      failure: (failure) => fail('expected success, got $failure'),
    );
  });

  test(
    'accumulates evidence across a retake instead of keeping only the latest',
    () async {
      final store = InMemorySecureKeyValueStore();
      final attempts = LocalSimulationAttemptRepository(
        store,
        clock: () => fixedTime,
      );
      final repository = WmsCareerPassportRepository(
        attemptRepository: attempts,
      );

      final first = await attempts.createAttempt(
        candidateId: candidateId,
        missionId: WorkplaceSimulationController.missionId,
        missionVersion: '1.0.0',
        scenarioSeed: 1,
      );
      await attempts.saveAttempt(first.copyWith(state: MissionState.completed));
      await attempts.saveResult(candidateId, _result(first, score: 60));
      await attempts.clearActiveAttempt(
        candidateId,
        WorkplaceSimulationController.missionId,
      );

      final retake = await attempts.createAttempt(
        candidateId: candidateId,
        missionId: WorkplaceSimulationController.missionId,
        missionVersion: '1.0.0',
        scenarioSeed: 3,
      );
      await attempts.saveAttempt(
        retake.copyWith(state: MissionState.completed),
      );
      await attempts.saveResult(candidateId, _result(retake, score: 90));

      final result = await repository.loadEvidence(candidateId);

      result.when(
        success: (evidence) {
          expect(evidence, hasLength(2));
          expect(
            evidence.map((e) => e.attemptId),
            containsAll([first.id, retake.id]),
          );
        },
        failure: (failure) => fail('expected success, got $failure'),
      );
    },
  );

  test('local-only repository cannot manage employer access', () async {
    final store = InMemorySecureKeyValueStore();
    final attempts = LocalSimulationAttemptRepository(
      store,
      clock: () => fixedTime,
    );
    final repository = WmsCareerPassportRepository(attemptRepository: attempts);

    expect(repository.canManageEmployerAccess, isFalse);
    final loaded = await repository.loadEmployerAccess(candidateId);
    loaded.when(
      success: (value) => expect(value, isEmpty),
      failure: (failure) => fail('expected success, got $failure'),
    );
    final granted = await repository.grantEmployerAccess(
      candidateId,
      'employer-1',
    );
    granted.when(
      success: (_) => fail('expected failure without a Supabase client'),
      failure: (failure) => expect(
        failure.message,
        'Employer access requires an account connection.',
      ),
    );
  });

  test('local-only repository cannot manage a share link', () async {
    final store = InMemorySecureKeyValueStore();
    final attempts = LocalSimulationAttemptRepository(
      store,
      clock: () => fixedTime,
    );
    final repository = WmsCareerPassportRepository(attemptRepository: attempts);

    expect(repository.canManageShareLink, isFalse);
    final loaded = await repository.loadShareLink(candidateId);
    loaded.when(
      success: (value) => expect(value, isNull),
      failure: (failure) => fail('expected success, got $failure'),
    );
    final created = await repository.createShareLink(candidateId);
    created.when(
      success: (_) => fail('expected failure without a Supabase client'),
      failure: (failure) =>
          expect(failure.message, 'Share links require an account connection.'),
    );
  });

  test('a share link still requires a configured API base URL even with '
      'Supabase configured', () async {
    final store = InMemorySecureKeyValueStore();
    final attempts = LocalSimulationAttemptRepository(
      store,
      clock: () => fixedTime,
    );
    // No supabaseClient is passed here either -- this repository has no
    // way to fake a SupabaseClient (a real client from supabase_flutter),
    // so this only proves apiBaseUrl alone isn't sufficient, mirroring
    // canManageShareLink's actual condition (both must be present).
    final repository = WmsCareerPassportRepository(
      attemptRepository: attempts,
      apiBaseUrl: 'https://api.example.com/v1',
    );

    expect(repository.canManageShareLink, isFalse);
  });
}

SimulationResult _result(SimulationAttempt attempt, {required int score}) {
  final competencyId =
      attempt.missionId == WorkplaceSimulationController.missionId
      ? 'receiving-accuracy'
      : 'put-away-accuracy';
  return SimulationResult(
    attemptId: attempt.id,
    missionId: attempt.missionId,
    missionVersion: attempt.missionVersion,
    scenarioSeed: attempt.scenarioSeed,
    status: MissionStatus.passed,
    overallScore: score.toDouble(),
    categoryScores: {competencyId: score.toDouble()},
    competencyScores: [
      CompetencyScore(competencyId: competencyId, score: score),
    ],
    mandatoryTasksCompleted: true,
    criticalErrors: const [],
    correctActions: const [],
    missedIssues: const [],
    evidence: [
      EvidenceRecord(
        id: '${attempt.id}-$competencyId',
        candidateId: attempt.candidateId,
        attemptId: attempt.id,
        missionId: attempt.missionId,
        missionVersion: attempt.missionVersion,
        scenarioSeed: attempt.scenarioSeed,
        competencyId: competencyId,
        score: score,
        evidenceType: EvidenceType.simulationObservation,
        title: 'Observed evidence',
        description: 'Generated from the append-only action trail.',
        issuedAt: DateTime.utc(2026, 8, 1, 9, 20),
        verificationStatus: EvidenceVerificationStatus.systemObserved,
      ),
    ],
    recommendedRemediationIds: const [],
    completedAt: DateTime.utc(2026, 8, 1, 9, 20),
  );
}
