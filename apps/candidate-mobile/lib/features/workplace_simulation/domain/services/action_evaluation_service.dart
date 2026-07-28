import '../simulation_content.dart';
import '../simulation_enums.dart';
import '../simulation_runtime.dart';

class ActionEvaluationService {
  const ActionEvaluationService();

  ActionOutcome evaluate(
    SimulationTask task,
    LearnerAction action, {
    GeneratedScenario? scenario,
  }) {
    if (action.isTechnical) {
      return ActionOutcome(
        actionId: action.id,
        taskId: task.id,
        categoryId: task.scoreCategoryId,
        outcomeType: OutcomeType.notApplicable,
        pointsAwarded: 0,
        maximumPoints: 0,
        feedbackCode: 'technical_event_excluded',
        competencyImpacts: const [],
      );
    }
    final matchingRule = task.evaluationRules
        .cast<TaskEvaluationRule?>()
        .firstWhere(
          (rule) => rule != null && _matches(rule, action, scenario),
          orElse: () => null,
        );
    final awarded = (matchingRule?.pointsAwarded ?? 0).clamp(
      0,
      task.maximumPoints,
    );
    final actionMaximum = task.repeatable && task.targetResourceIds.isNotEmpty
        ? (task.maximumPoints / task.targetResourceIds.length).ceil()
        : task.maximumPoints;
    return ActionOutcome(
      actionId: action.id,
      taskId: task.id,
      categoryId: task.scoreCategoryId,
      outcomeType: matchingRule?.outcomeType ?? OutcomeType.incorrect,
      pointsAwarded: awarded,
      maximumPoints: actionMaximum,
      feedbackCode: matchingRule?.feedbackCode ?? 'action_needs_review',
      competencyImpacts: [
        for (final mapping in task.competencyMappings)
          CompetencyImpact(
            competencyId: mapping.competencyId,
            scoreDelta: awarded * mapping.weight,
            maximumScore: actionMaximum * mapping.weight,
          ),
      ],
    );
  }

  bool _matches(
    TaskEvaluationRule rule,
    LearnerAction action,
    GeneratedScenario? scenario,
  ) {
    if (rule.actionType != action.actionType) return false;
    if (rule.targetId != null && rule.targetId != action.targetId) return false;
    for (final entry in rule.requiredPayload.entries) {
      if (action.payload[entry.key] != entry.value) return false;
    }
    if (rule.targetHasIssue != null ||
        rule.targetLacksIssue != null ||
        rule.targetMustBeCompliant) {
      final targetId = action.targetId;
      if (scenario == null || targetId == null) return false;
      final issues = scenario.resource(targetId).issues;
      if (rule.targetHasIssue != null &&
          issues.every((item) => item.issueType != rule.targetHasIssue)) {
        return false;
      }
      if (rule.targetLacksIssue != null &&
          issues.any((item) => item.issueType == rule.targetLacksIssue)) {
        return false;
      }
      if (rule.targetMustBeCompliant && issues.isNotEmpty) return false;
    }
    return true;
  }
}
