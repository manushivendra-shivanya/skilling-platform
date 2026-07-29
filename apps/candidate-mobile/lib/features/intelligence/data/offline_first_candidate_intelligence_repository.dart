import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/result.dart';
import '../domain/candidate_intelligence.dart';
import '../domain/candidate_intelligence_repository.dart';
import 'secure_candidate_intelligence_repository.dart';

class OfflineFirstCandidateIntelligenceRepository
    implements CandidateIntelligenceRepository {
  OfflineFirstCandidateIntelligenceRepository(this._local, this._remote);

  final SecureCandidateIntelligenceRepository _local;
  final SupabaseClient _remote;

  @override
  Future<Result<CandidateIntelligenceState>> load(String candidateId) async {
    final localResult = await _local.load(candidateId);
    final localState = localResult.when(
      success: (value) => value,
      failure: (_) => const CandidateIntelligenceState(),
    );
    try {
      final diagnosticRow = await _remote
          .from('diagnostic_results')
          .select()
          .eq('candidate_id', candidateId)
          .maybeSingle();
      final learningRow = await _remote
          .from('candidate_learning_state')
          .select()
          .eq('candidate_id', candidateId)
          .maybeSingle();
      final scoreRows = await _remote
          .from('simulation_scores')
          .select()
          .eq('candidate_id', candidateId)
          .order('completed_at');
      final evidenceRows = await _remote
          .from('competency_evidence')
          .select()
          .eq('candidate_id', candidateId)
          .order('created_at');

      final remoteState = CandidateIntelligenceState(
        diagnosticResult: diagnosticRow == null
            ? localState.diagnosticResult
            : DiagnosticResult.fromJson(
                diagnosticRow['result'] as Map<String, Object?>,
              ),
        learningProgress: learningRow == null
            ? localState.learningProgress
            : LearningProgressRecord(
                downloadedUnitIds:
                    (learningRow['downloaded_unit_ids'] as List<Object?>)
                        .whereType<String>()
                        .toSet(),
                completedUnitIds:
                    (learningRow['completed_unit_ids'] as List<Object?>)
                        .whereType<String>()
                        .toSet(),
              ),
        simulationScores: scoreRows
            .map(
              (row) => SimulationScore.fromJson(
                row['result'] as Map<String, Object?>,
              ),
            )
            .toList(),
        evidence: evidenceRows
            .map(
              (row) => EvidenceRecord.fromJson(
                row['evidence'] as Map<String, Object?>,
              ),
            )
            .toList(),
      );
      await _local.save(candidateId, remoteState);
      return Success(remoteState);
    } on PostgrestException {
      return Success(
        localState.copyWith(
          pendingSyncCount: localState.pendingSyncCount == 0
              ? 1
              : localState.pendingSyncCount,
        ),
      );
    }
  }

  @override
  Future<Result<CandidateIntelligenceState>> save(
    String candidateId,
    CandidateIntelligenceState state,
  ) async {
    final pendingState = state.copyWith(
      pendingSyncCount: state.pendingSyncCount + 1,
    );
    final localResult = await _local.save(candidateId, pendingState);
    if (localResult is ResultFailure<CandidateIntelligenceState>) {
      return localResult;
    }
    try {
      final diagnostic = state.diagnosticResult;
      if (diagnostic != null) {
        await _remote.from('diagnostic_results').upsert({
          'candidate_id': candidateId,
          'definition_version': diagnostic.definitionVersion,
          'recommended_role_code': diagnostic.recommendedRoleCode,
          'result': diagnostic.toJson(),
          'completed_at': diagnostic.completedAt.toUtc().toIso8601String(),
        }, onConflict: 'candidate_id');
      }
      await _remote.from('candidate_learning_state').upsert({
        'candidate_id': candidateId,
        'downloaded_unit_ids': state.learningProgress.downloadedUnitIds
            .toList(),
        'completed_unit_ids': state.learningProgress.completedUnitIds.toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'candidate_id');
      for (final score in state.simulationScores) {
        final startedAt = score.events.isEmpty
            ? score.completedAt
            : score.events.first.clientTime;
        await _remote
            .from('simulation_attempts')
            .upsert(
              {
                'id': score.attemptId,
                'candidate_id': candidateId,
                'simulation_version': score.simulationVersion,
                'status': 'active',
                'started_at': startedAt.toUtc().toIso8601String(),
              },
              onConflict: 'id',
              ignoreDuplicates: true,
            );
        if (score.events.isNotEmpty) {
          await _remote
              .from('simulation_events')
              .upsert(
                [
                  for (final event in score.events)
                    {
                      'attempt_id': score.attemptId,
                      'sequence': event.sequence,
                      'event_type': event.type,
                      'payload': event.payload,
                      'client_time': event.clientTime.toUtc().toIso8601String(),
                      'is_technical': event.isTechnical,
                    },
                ],
                onConflict: 'attempt_id,sequence',
                ignoreDuplicates: true,
              );
        }
        await _remote
            .from('simulation_attempts')
            .update({
              'status': 'scored',
              'submitted_at': score.completedAt.toUtc().toIso8601String(),
            })
            .eq('id', score.attemptId);
        await _remote.from('simulation_scores').upsert({
          'attempt_id': score.attemptId,
          'candidate_id': candidateId,
          'simulation_version': score.simulationVersion,
          'total_score': score.totalScore,
          'result': score.toJson(),
          'completed_at': score.completedAt.toUtc().toIso8601String(),
        }, onConflict: 'attempt_id');
      }
      for (final item in state.evidence) {
        await _remote.from('competency_evidence').upsert({
          'id': item.id,
          'candidate_id': candidateId,
          'competency_code': item.competencyCode,
          'source_type': item.sourceType,
          'score': item.score,
          'evidence': item.toJson(),
          'created_at': item.createdAt.toUtc().toIso8601String(),
        }, onConflict: 'id');
      }
      final synced = state.copyWith(pendingSyncCount: 0);
      await _local.save(candidateId, synced);
      return Success(synced);
    } on PostgrestException {
      return Success(pendingState);
    }
  }
}
