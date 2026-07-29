import '../simulation_content.dart';
import '../simulation_enums.dart';
import '../simulation_runtime.dart';

class CriticalErrorService {
  const CriticalErrorService();

  List<TriggeredCriticalError> detect({
    required MissionDefinition mission,
    required GeneratedScenario scenario,
    required List<LearnerAction> actions,
    required bool mandatoryInspectionCompleted,
  }) {
    final triggered = <TriggeredCriticalError>[];
    for (final rule in mission.criticalErrorRules) {
      if (rule.id == 'approve-without-inspection') continue;
      final matched = actions.any((action) => _matches(rule, action, scenario));
      if (matched) triggered.add(_fromRule(rule));
    }

    final finalDecision = actions.where(
      (item) => item.actionType == ActionType.makeDecision,
    );
    final approvedWithoutInspection =
        finalDecision.any(
          (item) =>
              item.payload['decision'] == 'accept_complete' ||
              item.payload['decision'] == 'partially_accept',
        ) &&
        !mandatoryInspectionCompleted;
    if (approvedWithoutInspection) {
      final rule = mission.criticalErrorRules.firstWhere(
        (item) => item.id == 'approve-without-inspection',
      );
      if (triggered.every((item) => item.ruleId != rule.id)) {
        triggered.add(_fromRule(rule));
      }
    }
    return triggered;
  }

  bool _matches(
    CriticalErrorRule rule,
    LearnerAction action,
    GeneratedScenario scenario,
  ) {
    if (action.isTechnical || action.actionType != rule.actionType) {
      return false;
    }
    if (rule.selectedDisposition != null &&
        action.payload['disposition'] != rule.selectedDisposition!.wireName) {
      return false;
    }
    for (final entry in rule.requiredPayload.entries) {
      if (action.payload[entry.key] != entry.value) return false;
    }
    if (rule.targetHasIssue == null) return true;
    final targetId = action.targetId;
    if (targetId == null) return false;
    return scenario
        .resource(targetId)
        .issues
        .any((issue) => issue.issueType == rule.targetHasIssue);
  }

  TriggeredCriticalError _fromRule(CriticalErrorRule rule) =>
      TriggeredCriticalError(
        ruleId: rule.id,
        title: rule.title,
        feedback: rule.feedback,
        severity: rule.severity,
        scorePenalty: rule.scorePenalty,
        preventsPassing: rule.preventsPassing,
      );
}
