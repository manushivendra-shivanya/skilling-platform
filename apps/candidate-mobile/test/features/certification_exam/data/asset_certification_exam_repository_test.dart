import 'package:candidate_mobile/features/certification_exam/data/asset_certification_exam_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the real warehouse operations exam asset', () async {
    const repository = AssetCertificationExamRepository();

    final result = await repository.loadExam();

    result.when(
      success: (exam) {
        expect(exam.id, 'warehouse_operations_exam_v1');
        expect(exam.questions, hasLength(12));
        expect(exam.passThresholdPercent, 70);
        expect(exam.timeLimit, const Duration(minutes: 15));
        expect(
          exam.questions.map((q) => q.competencyId).toSet().length,
          12,
          reason: 'each pilot question should target a distinct competency',
        );
        for (final question in exam.questions) {
          expect(question.options.length, greaterThanOrEqualTo(2));
          expect(
            question.options.any((o) => o.id == question.correctOptionId),
            isTrue,
          );
        }
      },
      failure: (failure) => fail('expected success, got $failure'),
    );
  });
}
