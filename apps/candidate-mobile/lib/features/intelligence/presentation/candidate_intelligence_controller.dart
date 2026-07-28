import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/candidate_intelligence.dart';

final candidateIntelligenceControllerProvider =
    AsyncNotifierProvider<
      CandidateIntelligenceController,
      CandidateIntelligenceState
    >(CandidateIntelligenceController.new);

class CandidateIntelligenceController
    extends AsyncNotifier<CandidateIntelligenceState> {
  String? _candidateId;

  @override
  Future<CandidateIntelligenceState> build() async {
    final sessionResult = await ref
        .read(candidateSessionRepositoryProvider)
        .readSession();
    final session = sessionResult.when(
      success: (value) => value,
      failure: (failure) => throw failure,
    );
    if (session == null || !session.isAuthenticated) {
      throw const AuthenticationFailure(
        'Sign in again to access your pathway.',
      );
    }
    _candidateId = session.candidateId;
    final result = await ref
        .read(candidateIntelligenceRepositoryProvider)
        .load(session.candidateId);
    return result.when(
      success: (value) => value,
      failure: (failure) => throw failure,
    );
  }

  Future<AppFailure?> saveDiagnostic(DiagnosticResult result) {
    final current = state.valueOrNull;
    if (current == null) {
      return Future.value(
        const StorageFailure('Your pathway is still loading. Please retry.'),
      );
    }
    final evidence = [
      ...current.evidence.where((item) => item.sourceType != 'diagnostic'),
      for (final item in result.competencies)
        EvidenceRecord(
          id: 'diagnostic-${result.definitionVersion}-${item.competencyCode}',
          competencyCode: item.competencyCode,
          sourceType: 'diagnostic',
          score: item.level * 25,
          explanation: item.explanation,
          createdAt: result.completedAt,
        ),
    ];
    return _save(
      current.copyWith(diagnosticResult: result, evidence: evidence),
    );
  }

  Future<AppFailure?> updateLearning({
    required Set<String> downloadedUnitIds,
    required Set<String> completedUnitIds,
  }) {
    final current = state.valueOrNull;
    if (current == null) {
      return Future.value(
        const StorageFailure('Learning progress is still loading.'),
      );
    }
    return _save(
      current.copyWith(
        learningProgress: LearningProgressRecord(
          downloadedUnitIds: downloadedUnitIds,
          completedUnitIds: completedUnitIds,
        ),
      ),
    );
  }

  Future<AppFailure?> saveSimulation(SimulationScore score) {
    final current = state.valueOrNull;
    if (current == null) {
      return Future.value(
        const StorageFailure('Simulation history is still loading.'),
      );
    }
    final scores = [
      ...current.simulationScores.where(
        (item) => item.attemptId != score.attemptId,
      ),
      score,
    ];
    final evidence = [
      ...current.evidence,
      EvidenceRecord(
        id: 'simulation-${score.attemptId}-inventory',
        competencyCode: 'inventory_accuracy',
        sourceType: 'simulation',
        score: score.dimensionScores['accuracy'] ?? 0,
        explanation: score.explanation,
        createdAt: score.completedAt,
      ),
      EvidenceRecord(
        id: 'simulation-${score.attemptId}-escalation',
        competencyCode: 'safe_escalation',
        sourceType: 'simulation',
        score: score.dimensionScores['safe_escalation'] ?? 0,
        explanation: score.explanation,
        createdAt: score.completedAt,
      ),
    ];
    return _save(
      current.copyWith(simulationScores: scores, evidence: evidence),
    );
  }

  Future<AppFailure?> _save(CandidateIntelligenceState next) async {
    final candidateId = _candidateId;
    if (candidateId == null) {
      return const AuthenticationFailure('Sign in again to save progress.');
    }
    state = AsyncData(next);
    final result = await ref
        .read(candidateIntelligenceRepositoryProvider)
        .save(candidateId, next);
    return result.when(
      success: (saved) {
        state = AsyncData(saved);
        return null;
      },
      failure: (failure) {
        state = AsyncData(next);
        return failure;
      },
    );
  }

  void retry() => ref.invalidateSelf();
}
