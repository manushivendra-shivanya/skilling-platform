import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedTime = DateTime.utc(2026, 7, 28, 10);

  test('persists candidate-owned attempts and append-only actions', () async {
    final repository = LocalSimulationAttemptRepository(
      InMemorySecureKeyValueStore(),
      clock: () => fixedTime,
    );
    final attempt = await repository.createAttempt(
      candidateId: 'candidate-1',
      missionId: 'mission-1',
      missionVersion: '1.0.0',
      scenarioSeed: 42,
    );
    final action = _action(attempt.id, sequence: 1);
    final appended = await repository.appendAction(action);

    expect(appended.actions, [action]);
    await expectLater(
      repository.appendAction(_action(attempt.id, sequence: 3)),
      throwsFormatException,
    );
    await expectLater(
      repository.saveAttempt(attempt.copyWith(actions: const [])),
      throwsStateError,
    );
  });

  test(
    'retry creates a fresh versioned attempt with incremented number',
    () async {
      var tick = 0;
      final repository = LocalSimulationAttemptRepository(
        InMemorySecureKeyValueStore(),
        clock: () => fixedTime.add(Duration(microseconds: tick++)),
      );
      final first = await repository.createAttempt(
        candidateId: 'candidate-1',
        missionId: 'mission-1',
        missionVersion: '1.0.0',
        scenarioSeed: 42,
      );
      await repository.clearActiveAttempt('candidate-1', 'mission-1');
      final retry = await repository.createAttempt(
        candidateId: 'candidate-1',
        missionId: 'mission-1',
        missionVersion: '1.0.0',
        scenarioSeed: 43,
      );

      expect(retry.id, isNot(first.id));
      expect(retry.attemptNumber, 2);
      expect(retry.state, MissionState.notStarted);
      expect(retry.actions, isEmpty);
    },
  );
}

LearnerAction _action(String attemptId, {required int sequence}) =>
    LearnerAction(
      id: 'action-$sequence',
      attemptId: attemptId,
      missionId: 'mission-1',
      stageId: 'stage-1',
      taskId: 'task-1',
      actionType: ActionType.confirmAction,
      targetId: null,
      payload: const {},
      sequenceNumber: sequence,
      simulationTimeSeconds: 5,
      createdAt: DateTime.utc(2026, 7, 28, 10),
    );
