import 'package:candidate_mobile/features/micro_lessons/domain/micro_lesson_assessment_attempt.dart';
import 'package:candidate_mobile/features/micro_lessons/domain/micro_lesson_evidence_generation_service.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = MicroLessonEvidenceGenerationService();
  final submittedAt = DateTime.utc(2026, 8, 1, 9);

  test('generates one systemObserved EvidenceRecord per competency tag', () {
    final attempt = MicroLessonAssessmentAttempt(
      id: 'attempt-1',
      candidateId: 'candidate-1',
      clipId: 'clip-1',
      clipTitle: 'Frozen receiving check',
      competencyTags: const [
        'cold_chain_receiving_check',
        'food_safety_compliance',
      ],
      selectedAnswerId: 'record',
      correctAnswerId: 'record',
      submittedAt: submittedAt,
      auditEvents: const [],
    );

    final evidence = service.generate(attempt);

    expect(evidence, hasLength(2));
    for (final record in evidence) {
      expect(record.candidateId, 'candidate-1');
      expect(record.attemptId, 'attempt-1');
      expect(record.missionId, 'clip-1');
      expect(record.score, 100);
      expect(record.evidenceType, EvidenceType.microLessonAssessment);
      expect(
        record.verificationStatus,
        EvidenceVerificationStatus.systemObserved,
      );
      expect(record.issuedAt, submittedAt);
      expect(record.description, contains('Frozen receiving check'));
    }
    expect(
      evidence.map((record) => record.id),
      containsAll([
        'attempt-1-cold_chain_receiving_check',
        'attempt-1-food_safety_compliance',
      ]),
    );
    expect(
      evidence
          .firstWhere(
            (record) => record.competencyId == 'cold_chain_receiving_check',
          )
          .title,
      'Observed Cold Chain Receiving Check',
    );
  });

  test('scores an incorrect attempt at 0', () {
    final attempt = MicroLessonAssessmentAttempt(
      id: 'attempt-2',
      candidateId: 'candidate-1',
      clipId: 'clip-1',
      clipTitle: 'Frozen receiving check',
      competencyTags: const ['cold_chain_receiving_check'],
      selectedAnswerId: 'accept',
      correctAnswerId: 'record',
      submittedAt: submittedAt,
      auditEvents: const [],
    );

    final evidence = service.generate(attempt);

    expect(evidence.single.score, 0);
  });

  test('generates nothing for a clip with no competency tags', () {
    final attempt = MicroLessonAssessmentAttempt(
      id: 'attempt-3',
      candidateId: 'candidate-1',
      clipId: 'clip-1',
      clipTitle: 'Frozen receiving check',
      competencyTags: const [],
      selectedAnswerId: 'record',
      correctAnswerId: 'record',
      submittedAt: submittedAt,
      auditEvents: const [],
    );

    expect(service.generate(attempt), isEmpty);
  });
}
