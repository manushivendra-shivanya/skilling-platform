import 'package:candidate_mobile/features/intelligence/domain/candidate_intelligence.dart';
import 'package:candidate_mobile/features/intelligence/domain/diagnostic_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scores every competency and returns an explainable role pathway', () {
    final result = DiagnosticEngine.score(
      selectedOptionIndexes: {
        'inventory-count': 1,
        'damaged-carton': 1,
        'dispatch-priority': 0,
        'shift-handover': 1,
      },
      completedAt: DateTime.utc(2026, 7, 28),
    );

    expect(result.definitionVersion, 'logistics-diagnostic-v1');
    expect(result.competencies, hasLength(4));
    expect(result.averageLevel, 3);
    expect(
      LogisticsIntelligenceCatalog.roles
          .map((role) => role.code)
          .contains(result.recommendedRoleCode),
      isTrue,
    );
    expect(
      result.competencies.every((item) => item.explanation.isNotEmpty),
      isTrue,
    );
    expect(
      result.competencies.every((item) => item.improvement.isNotEmpty),
      isTrue,
    );
  });

  test('rejects an incomplete diagnostic instead of inventing a result', () {
    expect(
      () => DiagnosticEngine.score(
        selectedOptionIndexes: const {'inventory-count': 1},
      ),
      throwsFormatException,
    );
  });
}
