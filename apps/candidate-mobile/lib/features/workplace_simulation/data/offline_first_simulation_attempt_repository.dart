import 'dart:convert';

import '../../../core/storage/secure_key_value_store.dart';
import '../domain/simulation_repositories.dart';
import '../domain/simulation_runtime.dart';
import 'wms_remote_sync_client.dart';

class OfflineFirstSimulationAttemptRepository
    implements SimulationAttemptRepository {
  factory OfflineFirstSimulationAttemptRepository({
    required SimulationAttemptRepository local,
    required SecureKeyValueStore store,
    required WmsRemoteSyncClient remote,
  }) => OfflineFirstSimulationAttemptRepository._(local, store, remote);

  OfflineFirstSimulationAttemptRepository._(
    this._local,
    this._store,
    this._remote,
  );

  final SimulationAttemptRepository _local;
  final SecureKeyValueStore _store;
  final WmsRemoteSyncClient _remote;

  @override
  Future<SimulationAttempt> createAttempt({
    required String candidateId,
    required String missionId,
    required String missionVersion,
    required int scenarioSeed,
    String? scenarioId,
    GeneratedScenario? generatedScenario,
  }) async {
    final attempt = await _local.createAttempt(
      candidateId: candidateId,
      missionId: missionId,
      missionVersion: missionVersion,
      scenarioSeed: scenarioSeed,
      scenarioId: scenarioId,
      generatedScenario: generatedScenario,
    );
    await _queueAndTrySync(attempt, generatedScenario: generatedScenario);
    return attempt;
  }

  @override
  Future<SimulationAttempt?> getActiveAttempt(
    String candidateId,
    String missionId,
  ) => _local.getActiveAttempt(candidateId, missionId);

  @override
  Future<void> saveAttempt(SimulationAttempt attempt) async {
    await _local.saveAttempt(attempt);
    await _queueAndTrySync(attempt);
  }

  @override
  Future<void> commitOperationalUpdate(SimulationAttempt attempt) async {
    await _local.commitOperationalUpdate(attempt);
    await _queueAndTrySync(attempt);
  }

  @override
  Future<SimulationAttempt> appendAction(LearnerAction action) async {
    final updated = await _local.appendAction(action);
    await _queueAndTrySync(updated);
    return updated;
  }

  @override
  Future<SimulationAttempt> appendAuditEvent(AttemptAuditEvent event) async {
    final updated = await _local.appendAuditEvent(event);
    await _queueAndTrySync(updated);
    return updated;
  }

  @override
  Future<SimulationAttempt> startShift({
    required SimulationAttempt startedAttempt,
    required AttemptAuditEvent requestedEvent,
    required AttemptAuditEvent startedEvent,
  }) async {
    final updated = await _local.startShift(
      startedAttempt: startedAttempt,
      requestedEvent: requestedEvent,
      startedEvent: startedEvent,
    );
    await _queueAndTrySync(updated);
    return updated;
  }

  @override
  Future<void> saveResult(String candidateId, SimulationResult result) async {
    await _local.saveResult(candidateId, result);
    final active = await _local.getActiveAttempt(candidateId, result.missionId);
    if (active != null && active.id == result.attemptId) {
      await _queueAndTrySync(active, result: result);
    }
  }

  @override
  Future<SimulationResult?> getResult(String candidateId, String attemptId) =>
      _local.getResult(candidateId, attemptId);

  /// Reads this device's local history only -- it is not merged with
  /// whatever the BFF has synced from other devices. Fine for a
  /// single-device candidate; a genuinely multi-device history needs a
  /// remote read, which this offline-first adapter deliberately never does.
  @override
  Future<List<SimulationResult>> listResults(
    String candidateId,
    String missionId,
  ) => _local.listResults(candidateId, missionId);

  @override
  Future<void> clearActiveAttempt(String candidateId, String missionId) =>
      _local.clearActiveAttempt(candidateId, missionId);

  @override
  Future<int> pendingSyncCount(String candidateId) async {
    final ids = await _pendingIds(candidateId);
    return ids.length;
  }

  @override
  Future<void> flushPendingSyncs(String candidateId) async {
    final ids = await _pendingIds(candidateId);
    for (final attemptId in ids) {
      final snapshot = await _readSnapshot(candidateId, attemptId);
      if (snapshot == null) continue;
      try {
        await _remote.sync(
          attempt: snapshot.attempt,
          result: snapshot.result,
          generatedScenario: snapshot.generatedScenario,
        );
        await _removeSnapshot(candidateId, attemptId);
      } catch (_) {
        // Keep the snapshot queued. The controller can retry by calling this
        // method again when connectivity or authentication is restored.
      }
    }
  }

  Future<void> _queueAndTrySync(
    SimulationAttempt attempt, {
    SimulationResult? result,
    GeneratedScenario? generatedScenario,
  }) async {
    await _writeSnapshot(
      attempt,
      result: result,
      generatedScenario: generatedScenario,
    );
    try {
      final retained = await _readSnapshot(attempt.candidateId, attempt.id);
      await _remote.sync(
        attempt: attempt,
        result: result,
        generatedScenario: generatedScenario ?? retained?.generatedScenario,
      );
      await _removeSnapshot(attempt.candidateId, attempt.id);
    } catch (_) {
      // Local-first guarantee: a remote outage must not make controller
      // mutations fail after the local write has already succeeded.
    }
  }

  Future<void> _writeSnapshot(
    SimulationAttempt attempt, {
    SimulationResult? result,
    GeneratedScenario? generatedScenario,
  }) async {
    final existing = await _readSnapshot(attempt.candidateId, attempt.id);
    final retainedResult = result ?? existing?.result;
    final retainedScenario = generatedScenario ?? existing?.generatedScenario;
    await _store.write(
      _snapshotKey(attempt.candidateId, attempt.id),
      jsonEncode({
        'attempt': attempt.toJson(),
        'result': retainedResult?.toJson(),
        'generatedScenario': retainedScenario?.toJson(),
      }),
    );
    final ids = await _pendingIds(attempt.candidateId);
    if (!ids.contains(attempt.id)) {
      await _store.write(
        _indexKey(attempt.candidateId),
        jsonEncode([...ids, attempt.id]),
      );
    }
  }

  Future<_PendingWmsSync?> _readSnapshot(
    String candidateId,
    String attemptId,
  ) async {
    final encoded = await _store.read(_snapshotKey(candidateId, attemptId));
    if (encoded == null) return null;
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, Object?>) return null;
    final attemptJson = decoded['attempt'];
    if (attemptJson is! Map<String, Object?>) return null;
    final resultJson = decoded['result'];
    final generatedScenarioJson = decoded['generatedScenario'];
    return _PendingWmsSync(
      attempt: SimulationAttempt.fromJson(attemptJson),
      result: resultJson is Map<String, Object?>
          ? SimulationResult.fromJson(resultJson)
          : null,
      generatedScenario: generatedScenarioJson is Map<String, Object?>
          ? GeneratedScenario.fromJson(generatedScenarioJson)
          : null,
    );
  }

  Future<void> _removeSnapshot(String candidateId, String attemptId) async {
    await _store.remove(_snapshotKey(candidateId, attemptId));
    final remaining = (await _pendingIds(
      candidateId,
    )).where((id) => id != attemptId).toList(growable: false);
    if (remaining.isEmpty) {
      await _store.remove(_indexKey(candidateId));
    } else {
      await _store.write(_indexKey(candidateId), jsonEncode(remaining));
    }
  }

  Future<List<String>> _pendingIds(String candidateId) async {
    final encoded = await _store.read(_indexKey(candidateId));
    if (encoded == null) return const [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) return const [];
    return decoded.whereType<String>().toList(growable: false);
  }

  String _indexKey(String candidateId) =>
      'candidate.wms.sync.pending.index.v1.${_safe(candidateId)}';

  String _snapshotKey(String candidateId, String attemptId) =>
      'candidate.wms.sync.pending.v1.${_safe(candidateId)}.${_safe(attemptId)}';

  String _safe(String value) => value.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
}

class _PendingWmsSync {
  const _PendingWmsSync({
    required this.attempt,
    this.result,
    this.generatedScenario,
  });

  final SimulationAttempt attempt;
  final SimulationResult? result;
  final GeneratedScenario? generatedScenario;
}
