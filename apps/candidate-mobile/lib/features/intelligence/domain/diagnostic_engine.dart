import 'candidate_intelligence.dart';

abstract final class DiagnosticEngine {
  static DiagnosticResult score({
    required Map<String, int> selectedOptionIndexes,
    DateTime? completedAt,
  }) {
    if (selectedOptionIndexes.length !=
        LogisticsIntelligenceCatalog.questions.length) {
      throw const FormatException('Every diagnostic question must be answered');
    }
    final results = <CompetencyResult>[];
    for (final question in LogisticsIntelligenceCatalog.questions) {
      final selectedIndex = selectedOptionIndexes[question.id];
      if (selectedIndex == null ||
          selectedIndex < 0 ||
          selectedIndex >= question.options.length) {
        throw const FormatException('Invalid diagnostic response');
      }
      final score = question.options[selectedIndex].score;
      results.add(
        CompetencyResult(
          competencyCode: question.competencyCode,
          level: score,
          explanation: score >= 3
              ? 'Your selected action follows the safe logistics workflow.'
              : 'Your selected action missed one or more safe workflow steps.',
          improvement: _improvementFor(question.competencyCode),
        ),
      );
    }
    final recommendedRole = _recommendRole(results);
    return DiagnosticResult(
      definitionVersion: LogisticsIntelligenceCatalog.diagnosticVersion,
      recommendedRoleCode: recommendedRole.code,
      competencies: results,
      completedAt: completedAt ?? DateTime.now(),
    );
  }

  static RoleDefinition _recommendRole(List<CompetencyResult> results) {
    final levels = {
      for (final result in results) result.competencyCode: result.level,
    };
    return LogisticsIntelligenceCatalog.roles.reduce((best, candidate) {
      return _distance(candidate, levels) < _distance(best, levels)
          ? candidate
          : best;
    });
  }

  static int _distance(RoleDefinition role, Map<String, int> levels) {
    return role.targetLevels.entries.fold(
      0,
      (distance, entry) =>
          distance + ((levels[entry.key] ?? 0) - entry.value).abs(),
    );
  }

  static String _improvementFor(String code) => switch (code) {
    'inventory_accuracy' =>
      'Practise recounting and preserving both physical and system records.',
    'safe_escalation' =>
      'Use the exception SOP: isolate, record facts, and notify the right owner.',
    'sla_prioritisation' =>
      'Compare deadlines and risk before choosing the next safe task.',
    _ =>
      'Use a factual handover: issue, action taken, owner, and outstanding risk.',
  };
}
