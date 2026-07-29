import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/intelligence/data/secure_candidate_intelligence_repository.dart';
import 'package:candidate_mobile/features/intelligence/domain/candidate_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips candidate-isolated intelligence and evidence', () async {
    final store = InMemorySecureKeyValueStore();
    final repository = SecureCandidateIntelligenceRepository(store);
    final completedAt = DateTime.utc(2026, 7, 28);
    final state = CandidateIntelligenceState(
      diagnosticResult: DiagnosticResult(
        definitionVersion: 'logistics-diagnostic-v1',
        recommendedRoleCode: 'inventory_executive',
        competencies: const [
          CompetencyResult(
            competencyCode: 'inventory_accuracy',
            level: 3,
            explanation: 'Safe workflow selected.',
            improvement: 'Continue practising.',
          ),
        ],
        completedAt: completedAt,
      ),
      learningProgress: const LearningProgressRecord(
        downloadedUnitIds: {'inventory-basics'},
        completedUnitIds: {'inventory-basics'},
      ),
      evidence: [
        EvidenceRecord(
          id: 'evidence-1',
          competencyCode: 'inventory_accuracy',
          sourceType: 'diagnostic',
          score: 75,
          explanation: 'Safe workflow selected.',
          createdAt: completedAt,
        ),
      ],
    );

    await repository.save('candidate-a', state);
    final restored = (await repository.load(
      'candidate-a',
    )).when(success: (value) => value, failure: (failure) => throw failure);
    final other = (await repository.load(
      'candidate-b',
    )).when(success: (value) => value, failure: (failure) => throw failure);

    expect(
      restored.diagnosticResult?.recommendedRoleCode,
      'inventory_executive',
    );
    expect(restored.learningProgress.completedUnitIds, {'inventory-basics'});
    expect(restored.evidence.single.score, 75);
    expect(other.diagnosticResult, isNull);
  });
}
