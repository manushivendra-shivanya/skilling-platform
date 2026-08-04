import 'package:candidate_mobile/features/certification_exam/domain/certification_exam.dart';
import 'package:candidate_mobile/features/certification_exam/domain/certification_exam_attempt.dart';
import 'package:candidate_mobile/features/certification_exam/domain/certification_exam_evidence_generation_service.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = CertificationExamEvidenceGenerationService();
  final submittedAt = DateTime.utc(2026, 8, 5, 9, 15);

  CertificationExam examWith(int passThresholdPercent) {
    return CertificationExam(
      id: 'exam-1',
      title: 'Warehouse Operations Certification',
      version: '1',
      description: 'Description',
      timeLimit: const Duration(minutes: 15),
      passThresholdPercent: passThresholdPercent,
      questions: const [
        CertificationExamQuestion(
          id: 'q1',
          competencyId: 'cold_chain_receiving_check',
          prompt: 'Prompt 1?',
          options: [
            ExamAnswerOption(id: 'correct', label: 'Correct', feedback: 'Good'),
            ExamAnswerOption(id: 'wrong', label: 'Wrong', feedback: 'Bad'),
          ],
          correctOptionId: 'correct',
        ),
        CertificationExamQuestion(
          id: 'q2',
          competencyId: 'ppe_compliance',
          prompt: 'Prompt 2?',
          options: [
            ExamAnswerOption(id: 'correct', label: 'Correct', feedback: 'Good'),
            ExamAnswerOption(id: 'wrong', label: 'Wrong', feedback: 'Bad'),
          ],
          correctOptionId: 'correct',
        ),
      ],
    );
  }

  CertificationExamAttempt attemptWith(List<QuestionResponse> responses) {
    return CertificationExamAttempt(
      id: 'attempt-1',
      candidateId: 'candidate-1',
      examId: 'exam-1',
      examVersion: '1',
      responses: responses,
      startedAt: submittedAt.subtract(const Duration(minutes: 12)),
      submittedAt: submittedAt,
    );
  }

  test(
    'generates one systemObserved EvidenceRecord per competency on a pass',
    () {
      final exam = examWith(70);
      final attempt = attemptWith(const [
        QuestionResponse(
          questionId: 'q1',
          competencyId: 'cold_chain_receiving_check',
          selectedOptionId: 'correct',
          correctOptionId: 'correct',
        ),
        QuestionResponse(
          questionId: 'q2',
          competencyId: 'ppe_compliance',
          selectedOptionId: 'correct',
          correctOptionId: 'correct',
        ),
      ]);

      final evidence = service.generate(attempt, exam);

      expect(evidence, hasLength(2));
      for (final record in evidence) {
        expect(record.candidateId, 'candidate-1');
        expect(record.attemptId, 'attempt-1');
        expect(record.missionId, 'exam-1');
        expect(record.missionVersion, '1');
        expect(record.score, 100);
        expect(record.evidenceType, EvidenceType.certificationExam);
        expect(
          record.verificationStatus,
          EvidenceVerificationStatus.systemObserved,
        );
        expect(record.issuedAt, submittedAt);
        expect(
          record.description,
          contains('Warehouse Operations Certification'),
        );
        expect(record.description, contains('100%'));
      }
      expect(
        evidence.map((record) => record.competencyId),
        containsAll(['cold_chain_receiving_check', 'ppe_compliance']),
      );
      expect(
        evidence
            .firstWhere((record) => record.competencyId == 'ppe_compliance')
            .title,
        'Certified: Ppe Compliance',
      );
    },
  );

  test(
    'generates no evidence when the attempt falls below the pass threshold',
    () {
      final exam = examWith(70);
      // 1 of 2 correct = 50%, below the 70% threshold.
      final attempt = attemptWith(const [
        QuestionResponse(
          questionId: 'q1',
          competencyId: 'cold_chain_receiving_check',
          selectedOptionId: 'correct',
          correctOptionId: 'correct',
        ),
        QuestionResponse(
          questionId: 'q2',
          competencyId: 'ppe_compliance',
          selectedOptionId: 'wrong',
          correctOptionId: 'correct',
        ),
      ]);

      expect(service.generate(attempt, exam), isEmpty);
    },
  );

  test('an attempt exactly at the pass threshold still generates evidence', () {
    final exam = examWith(50);
    final attempt = attemptWith(const [
      QuestionResponse(
        questionId: 'q1',
        competencyId: 'cold_chain_receiving_check',
        selectedOptionId: 'correct',
        correctOptionId: 'correct',
      ),
      QuestionResponse(
        questionId: 'q2',
        competencyId: 'ppe_compliance',
        selectedOptionId: 'wrong',
        correctOptionId: 'correct',
      ),
    ]);

    expect(service.generate(attempt, exam), hasLength(2));
  });

  test('deduplicates evidence when two questions share a competency', () {
    final exam = CertificationExam(
      id: 'exam-1',
      title: 'Test Exam',
      version: '1',
      description: 'Description',
      timeLimit: const Duration(minutes: 15),
      passThresholdPercent: 70,
      questions: const [
        CertificationExamQuestion(
          id: 'q1',
          competencyId: 'shared_tag',
          prompt: 'Prompt 1?',
          options: [
            ExamAnswerOption(id: 'correct', label: 'Correct', feedback: 'Good'),
          ],
          correctOptionId: 'correct',
        ),
        CertificationExamQuestion(
          id: 'q2',
          competencyId: 'shared_tag',
          prompt: 'Prompt 2?',
          options: [
            ExamAnswerOption(id: 'correct', label: 'Correct', feedback: 'Good'),
          ],
          correctOptionId: 'correct',
        ),
      ],
    );
    final attempt = attemptWith(const [
      QuestionResponse(
        questionId: 'q1',
        competencyId: 'shared_tag',
        selectedOptionId: 'correct',
        correctOptionId: 'correct',
      ),
      QuestionResponse(
        questionId: 'q2',
        competencyId: 'shared_tag',
        selectedOptionId: 'correct',
        correctOptionId: 'correct',
      ),
    ]);

    expect(service.generate(attempt, exam), hasLength(1));
  });
}
