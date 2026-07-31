import '../simulation_content.dart';
import '../simulation_enums.dart';
import '../simulation_runtime.dart';
import 'evidence_generation_service.dart';
import 'mission_progress_service.dart';

class MissionScoringService {
  const MissionScoringService({
    this.evidenceService = const EvidenceGenerationService(),
    this.progressService = const MissionProgressService(),
  });

  final EvidenceGenerationService evidenceService;
  final MissionProgressService progressService;

  SimulationResult score({
    required MissionDefinition mission,
    required SimulationAttempt attempt,
    required List<ActionOutcome> outcomes,
    required List<TriggeredCriticalError> criticalErrors,
    required List<RemediationRecommendation> remediation,
    DateTime? completedAt,
  }) {
    final passBlocked = criticalErrors.any((item) => item.preventsPassing);
    if (!passBlocked) {
      final earlyRule = _matchEarlyCompletion(mission, attempt, outcomes);
      if (earlyRule != null) {
        return _scoreEarlyCompletion(
          mission: mission,
          attempt: attempt,
          outcomes: outcomes,
          criticalErrors: criticalErrors,
          rule: earlyRule,
          issuedAt: completedAt ?? DateTime.now(),
        );
      }
    }
    final categoryScores = <String, double>{};
    for (final category in mission.scoringRule.categories) {
      final tasks = mission.tasks
          .where((item) => item.scoreCategoryId == category.id)
          .toList();
      final available = tasks.fold<int>(
        0,
        (sum, item) => sum + item.maximumPoints,
      );
      var earned = 0;
      for (final task in tasks) {
        final taskPoints = outcomes
            .where((item) => item.taskId == task.id)
            .fold<int>(0, (sum, item) => sum + item.pointsAwarded)
            .clamp(0, task.maximumPoints);
        earned += taskPoints;
      }
      categoryScores[category.id] = available == 0
          ? 0
          : earned / available * 100;
    }

    final rawOverall = mission.scoringRule.categories.fold<double>(
      0,
      (sum, category) =>
          sum + (categoryScores[category.id] ?? 0) * category.weight,
    );
    final penalty = criticalErrors.fold<int>(
      0,
      (sum, item) => sum + item.scorePenalty,
    );
    final overall = (rawOverall - penalty).clamp(0, 100).toDouble();
    final mandatoryCompleted = progressService.allMandatoryTasksCompleted(
      mission,
      attempt,
    );
    final status = passBlocked
        ? MissionStatus.criticalFailure
        : !mandatoryCompleted
        ? MissionStatus.incomplete
        : overall >= mission.scoringRule.minimumScore
        ? MissionStatus.passed
        : MissionStatus.retryRecommended;

    final achievedFeedback = outcomes
        .where(
          (item) =>
              item.outcomeType == OutcomeType.correct ||
              item.outcomeType == OutcomeType.partiallyCorrect,
        )
        .map((item) => item.feedbackCode)
        .toSet();
    final rules = mission.tasks.expand((item) => item.evaluationRules);
    final correctActions = rules
        .where(
          (item) =>
              item.correctActionLabel != null &&
              achievedFeedback.contains(item.feedbackCode),
        )
        .map((item) => item.correctActionLabel!)
        .toSet()
        .toList();
    final missedIssues = rules
        .where(
          (item) =>
              item.missedIssueCode != null &&
              !achievedFeedback.contains(item.feedbackCode),
        )
        .map((item) => item.missedIssueCode!)
        .toSet()
        .toList();
    final remediationIds = remediation
        .where((item) => item.triggerIssueTypes.any(missedIssues.contains))
        .map((item) => item.id)
        .toList();
    final competencyScores = evidenceService.competencyScores(outcomes);
    final issuedAt = completedAt ?? DateTime.now();
    final evidence = status == MissionStatus.incomplete
        ? const <EvidenceRecord>[]
        : evidenceService.generate(
            attempt: attempt,
            mission: mission,
            competencyScores: competencyScores,
            issuedAt: issuedAt,
          );

    return SimulationResult(
      attemptId: attempt.id,
      missionId: mission.id,
      missionVersion: mission.version,
      scenarioSeed: attempt.scenarioSeed,
      status: status,
      overallScore: double.parse(overall.toStringAsFixed(1)),
      categoryScores: categoryScores.map(
        (key, value) => MapEntry(key, double.parse(value.toStringAsFixed(1))),
      ),
      competencyScores: competencyScores,
      mandatoryTasksCompleted: mandatoryCompleted,
      criticalErrors: criticalErrors,
      correctActions: correctActions,
      missedIssues: missedIssues,
      evidence: evidence,
      recommendedRemediationIds: remediationIds,
      completedAt: issuedAt,
    );
  }

  EarlyCompletionRule? _matchEarlyCompletion(
    MissionDefinition mission,
    SimulationAttempt attempt,
    List<ActionOutcome> outcomes,
  ) {
    for (final rule in mission.earlyCompletionRules) {
      if (!rule.skipRemainingMandatoryTasks) continue;
      for (final action in attempt.actions) {
        if (action.taskId != rule.triggerTaskId ||
            action.actionType != rule.triggerActionType) {
          continue;
        }
        final payloadMatches = rule.requiredPayload.entries.every(
          (entry) => action.payload[entry.key] == entry.value,
        );
        if (!payloadMatches) continue;
        final outcome = outcomes.cast<ActionOutcome?>().firstWhere(
          (item) => item != null && item.actionId == action.id,
          orElse: () => null,
        );
        if (outcome != null && outcome.outcomeType == rule.requiredOutcome) {
          return rule;
        }
      }
    }
    return null;
  }

  /// Scores a terminal-exception outcome using only the categories touched
  /// before the triggering action, rather than penalising every downstream
  /// task the mission never expected this branch to reach.
  SimulationResult _scoreEarlyCompletion({
    required MissionDefinition mission,
    required SimulationAttempt attempt,
    required List<ActionOutcome> outcomes,
    required List<TriggeredCriticalError> criticalErrors,
    required EarlyCompletionRule rule,
    required DateTime issuedAt,
  }) {
    final touchedTaskIds = outcomes.map((item) => item.taskId).toSet();
    final categoryScores = <String, double>{};
    final relevantWeights = <double>[];
    for (final category in mission.scoringRule.categories) {
      final tasks = mission.tasks
          .where(
            (item) =>
                item.scoreCategoryId == category.id &&
                touchedTaskIds.contains(item.id),
          )
          .toList();
      if (tasks.isEmpty) {
        categoryScores[category.id] = 0;
        continue;
      }
      final available = tasks.fold<int>(
        0,
        (sum, item) => sum + item.maximumPoints,
      );
      final earned = tasks.fold<int>(
        0,
        (sum, task) =>
            sum +
            outcomes
                .where((item) => item.taskId == task.id)
                .fold<int>(0, (inner, item) => inner + item.pointsAwarded)
                .clamp(0, task.maximumPoints),
      );
      categoryScores[category.id] = available == 0
          ? 0
          : earned / available * 100;
      relevantWeights.add(category.weight);
    }
    final relevantWeightTotal = relevantWeights.fold<double>(
      0,
      (sum, weight) => sum + weight,
    );
    final overall = relevantWeightTotal == 0
        ? 0.0
        : mission.scoringRule.categories.fold<double>(
                0,
                (sum, category) =>
                    sum + (categoryScores[category.id] ?? 0) * category.weight,
              ) /
              relevantWeightTotal;
    final competencyScores = evidenceService.competencyScores(outcomes);
    return SimulationResult(
      attemptId: attempt.id,
      missionId: mission.id,
      missionVersion: mission.version,
      scenarioSeed: attempt.scenarioSeed,
      status: rule.resultStatus,
      overallScore: double.parse(overall.clamp(0, 100).toStringAsFixed(1)),
      categoryScores: categoryScores.map(
        (key, value) => MapEntry(key, double.parse(value.toStringAsFixed(1))),
      ),
      competencyScores: competencyScores,
      mandatoryTasksCompleted: true,
      criticalErrors: criticalErrors,
      correctActions: [rule.completionLabel],
      missedIssues: const [],
      evidence: evidenceService.generate(
        attempt: attempt,
        mission: mission,
        competencyScores: competencyScores,
        issuedAt: issuedAt,
      ),
      recommendedRemediationIds: const [],
      completedAt: issuedAt,
    );
  }
}
