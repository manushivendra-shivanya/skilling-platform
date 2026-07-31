import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/offline_first_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/wms_remote_sync_client.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedTime = DateTime.utc(2026, 7, 31, 10);

  test(
    'saves locally and queues pending sync when the BFF is unavailable',
    () async {
      final remote = _FakeWmsRemoteSyncClient(fail: true);
      final repository = _repository(remote, fixedTime);

      final attempt = await repository.createAttempt(
        candidateId: 'candidate-1',
        missionId: 'mission-1',
        missionVersion: '1.0.0',
        scenarioSeed: 42,
      );

      expect(remote.calls, 1);
      expect(await repository.pendingSyncCount('candidate-1'), 1);
      expect(
        await repository.getActiveAttempt('candidate-1', 'mission-1'),
        isNotNull,
      );
      expect(attempt.state, MissionState.notStarted);
    },
  );

  test('flushes a queued attempt once the remote sync recovers', () async {
    final remote = _FakeWmsRemoteSyncClient(fail: true);
    final repository = _repository(remote, fixedTime);
    await repository.createAttempt(
      candidateId: 'candidate-1',
      missionId: 'mission-1',
      missionVersion: '1.0.0',
      scenarioSeed: 42,
    );
    remote.fail = false;

    await repository.flushPendingSyncs('candidate-1');

    expect(remote.calls, 2);
    expect(await repository.pendingSyncCount('candidate-1'), 0);
  });

  test(
    'syncs result and generated evidence without changing local result storage',
    () async {
      final remote = _FakeWmsRemoteSyncClient();
      final repository = _repository(remote, fixedTime);
      final attempt = await repository.createAttempt(
        candidateId: 'candidate-1',
        missionId: 'mission-1',
        missionVersion: '1.0.0',
        scenarioSeed: 42,
      );
      final result = _result(attempt);

      await repository.saveResult('candidate-1', result);

      expect(remote.lastResult?.attemptId, attempt.id);
      expect(
        remote.lastResult?.evidence.single.verificationStatus,
        'systemObserved',
      );
      expect(
        await repository.getResult('candidate-1', attempt.id),
        isA<SimulationResult>(),
      );
    },
  );

  test(
    'keeps a queued result when a later attempt-only write happens offline',
    () async {
      final remote = _FakeWmsRemoteSyncClient(fail: true);
      final repository = _repository(remote, fixedTime);
      final attempt = await repository.createAttempt(
        candidateId: 'candidate-1',
        missionId: 'mission-1',
        missionVersion: '1.0.0',
        scenarioSeed: 42,
      );
      final result = _result(attempt);
      await repository.saveResult('candidate-1', result);
      final completed = attempt.copyWith(state: MissionState.completed);
      await repository.saveAttempt(completed);
      remote.fail = false;

      await repository.flushPendingSyncs('candidate-1');

      expect(remote.lastAttempt?.state, MissionState.completed);
      expect(remote.lastResult?.attemptId, attempt.id);
    },
  );

  test('queues and later flushes the generated scenario snapshot, retaining it '
      'across a later attempt-only write', () async {
    final remote = _FakeWmsRemoteSyncClient(fail: true);
    final repository = _repository(remote, fixedTime);
    final attempt = await repository.createAttempt(
      candidateId: 'candidate-1',
      missionId: 'mission-1',
      missionVersion: '1.0.0',
      scenarioSeed: 42,
      generatedScenario: _scenario(attemptScenarioSeed: 42),
    );
    final touched = attempt.copyWith(currentStageId: 'document-verification');
    await repository.saveAttempt(touched);
    remote.fail = false;

    await repository.flushPendingSyncs('candidate-1');

    expect(remote.lastGeneratedScenario?.seed, 42);
    expect(remote.lastAttempt?.currentStageId, 'document-verification');
  });
}

GeneratedScenario _scenario({required int attemptScenarioSeed}) =>
    GeneratedScenario(
      missionId: 'mission-1',
      missionVersion: '1.0.0',
      seed: attemptScenarioSeed,
      resources: const [],
    );

OfflineFirstSimulationAttemptRepository _repository(
  _FakeWmsRemoteSyncClient remote,
  DateTime fixedTime,
) {
  final store = InMemorySecureKeyValueStore();
  return OfflineFirstSimulationAttemptRepository(
    local: LocalSimulationAttemptRepository(store, clock: () => fixedTime),
    store: store,
    remote: remote,
  );
}

SimulationResult _result(SimulationAttempt attempt) => SimulationResult(
  attemptId: attempt.id,
  missionId: attempt.missionId,
  missionVersion: attempt.missionVersion,
  scenarioSeed: attempt.scenarioSeed,
  status: MissionStatus.passed,
  overallScore: 82,
  categoryScores: const {'receiving': 82},
  competencyScores: const [
    CompetencyScore(competencyId: 'receiving-accuracy', score: 82),
  ],
  mandatoryTasksCompleted: true,
  criticalErrors: const [],
  correctActions: const [],
  missedIssues: const [],
  evidence: [
    EvidenceRecord(
      id: 'evidence-1',
      candidateId: attempt.candidateId,
      attemptId: attempt.id,
      missionId: attempt.missionId,
      missionVersion: attempt.missionVersion,
      scenarioSeed: attempt.scenarioSeed,
      competencyId: 'receiving-accuracy',
      score: 82,
      evidenceType: EvidenceType.simulationObservation,
      title: 'Receiving accuracy',
      description: 'Candidate completed the receiving simulation.',
      issuedAt: DateTime.utc(2026, 7, 31, 10, 20),
      verificationStatus: 'systemObserved',
    ),
  ],
  recommendedRemediationIds: const [],
  completedAt: DateTime.utc(2026, 7, 31, 10, 20),
);

class _FakeWmsRemoteSyncClient implements WmsRemoteSyncClient {
  _FakeWmsRemoteSyncClient({this.fail = false});

  bool fail;
  int calls = 0;
  SimulationAttempt? lastAttempt;
  SimulationResult? lastResult;
  GeneratedScenario? lastGeneratedScenario;

  @override
  Future<void> sync({
    required SimulationAttempt attempt,
    SimulationResult? result,
    GeneratedScenario? generatedScenario,
  }) async {
    calls += 1;
    if (fail) {
      throw const NetworkFailure('offline');
    }
    lastAttempt = attempt;
    lastResult = result;
    lastGeneratedScenario = generatedScenario;
  }
}
