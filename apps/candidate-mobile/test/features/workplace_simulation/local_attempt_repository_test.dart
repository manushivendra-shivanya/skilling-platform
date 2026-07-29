import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_runtime.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/workplace_task_drafts.dart';
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

  test('persists a continuously sequenced unscored audit stream', () async {
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
    final event = AttemptAuditEvent(
      id: '${attempt.id}-event-1',
      attemptId: attempt.id,
      missionId: attempt.missionId,
      missionVersion: attempt.missionVersion,
      eventType: AttemptAuditEventType.briefingAcknowledged,
      screenId: 'supervisor-briefing',
      sequenceNumber: 1,
      simulationElapsedSeconds: 0,
      occurredAt: fixedTime,
      payload: const {'rulesVersion': '1.0.0'},
    );

    final updated = await repository.appendAuditEvent(event);

    expect(updated.auditEvents, [event]);
    expect(updated.actions, isEmpty);
    expect(event.toJson(), {
      'id': '${attempt.id}-event-1',
      'attemptId': attempt.id,
      'missionId': 'mission-1',
      'missionVersion': '1.0.0',
      'eventType': 'briefingAcknowledged',
      'screenId': 'supervisor-briefing',
      'targetId': null,
      'sequenceNumber': 1,
      'simulationElapsedSeconds': 0,
      'occurredAt': fixedTime.toIso8601String(),
      'payload': const {'rulesVersion': '1.0.0'},
    });
    await expectLater(
      repository.appendAuditEvent(
        AttemptAuditEvent(
          id: '${attempt.id}-event-3',
          attemptId: attempt.id,
          missionId: attempt.missionId,
          missionVersion: attempt.missionVersion,
          eventType: AttemptAuditEventType.shiftStarted,
          screenId: 'supervisor-briefing',
          sequenceNumber: 3,
          simulationElapsedSeconds: 0,
          occurredAt: fixedTime,
        ),
      ),
      throwsFormatException,
    );
  });

  test(
    'failed atomic shift start leaves timer and audit stream unchanged',
    () async {
      final store = _FailingSecureStore();
      final repository = LocalSimulationAttemptRepository(
        store,
        clock: () => fixedTime,
      );
      final created = await repository.createAttempt(
        candidateId: 'candidate-1',
        missionId: 'mission-1',
        missionVersion: '1.0.0',
        scenarioSeed: 42,
      );
      final briefing = created.copyWith(state: MissionState.briefing);
      await repository.saveAttempt(briefing);
      final started = briefing.copyWith(
        state: MissionState.inProgress,
        shiftStartedAt: fixedTime,
        timerResumedAt: fixedTime,
        timerStatus: SimulationTimerStatus.running,
      );
      final requested = _auditEvent(
        briefing,
        AttemptAuditEventType.shiftStartRequested,
        1,
        fixedTime,
      );
      final shiftStarted = _auditEvent(
        started,
        AttemptAuditEventType.shiftStarted,
        2,
        fixedTime,
      );
      store.failNextWrite = true;

      await expectLater(
        repository.startShift(
          startedAttempt: started,
          requestedEvent: requested,
          startedEvent: shiftStarted,
        ),
        throwsStateError,
      );
      final restored = await repository.getActiveAttempt(
        'candidate-1',
        'mission-1',
      );
      expect(restored!.state, MissionState.briefing);
      expect(restored.shiftStartedAt, isNull);
      expect(restored.timerStatus, SimulationTimerStatus.notStarted);
      expect(restored.auditEvents, isEmpty);
    },
  );

  test('persists operational drafts and their revision metadata', () async {
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
    final updated = attempt.copyWith(
      documentReviewDraft: DocumentReviewDraft(
        attemptId: attempt.id,
        taskId: 'verify-documents',
        findings: [
          DocumentFinding(
            id: 'finding-1',
            sourceDocument: DocumentSource.both,
            itemReference: 'SKU-1002',
            findingType: DocumentFindingType.quantityMismatch,
            learnerNotes: 'Check quantity',
            createdAt: fixedTime,
            updatedAt: fixedTime,
            revisionNumber: 2,
          ),
        ],
        status: OperationalDraftStatus.draft,
        createdAt: fixedTime,
        updatedAt: fixedTime,
      ),
      receivingCountDraft: ReceivingCountDraft(
        attemptId: attempt.id,
        taskId: 'confirm-received-counts',
        shipmentConfirmed: true,
        countEntries: [
          ReceivingCountEntry(
            id: 'count-1',
            cartonId: 'carton-002',
            sku: 'SKU-1002',
            enteredQuantity: 18,
            countMethod: CountMethod.individual,
            learnerNotes: '',
            createdAt: fixedTime,
            updatedAt: fixedTime,
            revisionNumber: 3,
          ),
        ],
        status: OperationalDraftStatus.draft,
        createdAt: fixedTime,
        updatedAt: fixedTime,
      ),
    );

    await repository.commitOperationalUpdate(updated);
    final restored = await repository.getActiveAttempt(
      'candidate-1',
      'mission-1',
    );

    expect(restored!.documentReviewDraft!.findings.single.revisionNumber, 2);
    expect(
      restored.receivingCountDraft!.countEntries.single.enteredQuantity,
      18,
    );
    expect(restored.receivingCountDraft!.countEntries.single.revisionNumber, 3);
  });
}

AttemptAuditEvent _auditEvent(
  SimulationAttempt attempt,
  AttemptAuditEventType type,
  int sequence,
  DateTime occurredAt,
) => AttemptAuditEvent(
  id: '${attempt.id}-event-$sequence',
  attemptId: attempt.id,
  missionId: attempt.missionId,
  missionVersion: attempt.missionVersion,
  eventType: type,
  screenId: 'supervisor-briefing',
  sequenceNumber: sequence,
  simulationElapsedSeconds: 0,
  occurredAt: occurredAt,
);

class _FailingSecureStore implements SecureKeyValueStore {
  final _delegate = InMemorySecureKeyValueStore();
  bool failNextWrite = false;

  @override
  Future<String?> read(String key) => _delegate.read(key);

  @override
  Future<void> remove(String key) => _delegate.remove(key);

  @override
  Future<void> write(String key, String value) {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('Injected persistence failure');
    }
    return _delegate.write(key, value);
  }
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
