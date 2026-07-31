import 'simulation_enums.dart';

typedef JsonMap = Map<String, Object?>;

class SimulationPack {
  const SimulationPack({
    required this.id,
    required this.version,
    required this.industry,
    required this.title,
    required this.status,
    required this.defaultLocale,
    required this.supportedLocales,
    required this.minimumEngineVersion,
  });

  final String id;
  final String version;
  final String industry;
  final String title;
  final String status;
  final String defaultLocale;
  final List<String> supportedLocales;
  final String minimumEngineVersion;

  factory SimulationPack.fromJson(JsonMap json) => SimulationPack(
    id: json.string('id'),
    version: json.string('version'),
    industry: json.string('industry'),
    title: json.string('title'),
    status: json.string('status'),
    defaultLocale: json.string('defaultLocale'),
    supportedLocales: json.stringList('supportedLocales'),
    minimumEngineVersion: json.string('minimumEngineVersion'),
  );
}

class Workplace {
  const Workplace({
    required this.id,
    required this.packId,
    required this.name,
    required this.workplaceType,
    required this.description,
    required this.departmentIds,
    required this.operationalRules,
    required this.departments,
    required this.workstations,
  });

  final String id;
  final String packId;
  final String name;
  final String workplaceType;
  final String description;
  final List<String> departmentIds;
  final List<String> operationalRules;
  final List<Department> departments;
  final List<Workstation> workstations;

  factory Workplace.fromJson(JsonMap json) => Workplace(
    id: json.string('id'),
    packId: json.string('packId'),
    name: json.string('name'),
    workplaceType: json.string('workplaceType'),
    description: json.string('description'),
    departmentIds: json.stringList('departments'),
    operationalRules: json.stringList('operationalRules'),
    departments: json
        .mapList('departmentDefinitions')
        .map(Department.fromJson)
        .toList(growable: false),
    workstations: json
        .mapList('workstationDefinitions')
        .map(Workstation.fromJson)
        .toList(growable: false),
  );
}

class Department {
  const Department({
    required this.id,
    required this.workplaceId,
    required this.name,
    required this.description,
    required this.workstationIds,
    required this.processIds,
  });

  final String id;
  final String workplaceId;
  final String name;
  final String description;
  final List<String> workstationIds;
  final List<String> processIds;

  factory Department.fromJson(JsonMap json) => Department(
    id: json.string('id'),
    workplaceId: json.string('workplaceId'),
    name: json.string('name'),
    description: json.string('description'),
    workstationIds: json.stringList('workstations'),
    processIds: json.stringList('processes'),
  );
}

class Workstation {
  const Workstation({
    required this.id,
    required this.departmentId,
    required this.name,
    required this.workstationType,
    required this.description,
    required this.icon,
    required this.x,
    required this.y,
    required this.capabilities,
    required this.unlockRequirements,
  });

  final String id;
  final String departmentId;
  final String name;
  final String workstationType;
  final String description;
  final String icon;
  final double x;
  final double y;
  final List<String> capabilities;
  final List<UnlockRequirement> unlockRequirements;

  factory Workstation.fromJson(JsonMap json) {
    final position = json.object('position');
    final x = position.number('x').toDouble();
    final y = position.number('y').toDouble();
    if (x < 0 || x > 1 || y < 0 || y > 1) {
      throw const FormatException(
        'Workstation coordinates must be normalized from 0 to 1',
      );
    }
    return Workstation(
      id: json.string('id'),
      departmentId: json.string('departmentId'),
      name: json.string('name'),
      workstationType: json.string('workstationType'),
      description: json.string('description'),
      icon: json.string('icon'),
      x: x,
      y: y,
      capabilities: json.stringList('capabilities'),
      unlockRequirements: json
          .mapList('unlockRequirements')
          .map(UnlockRequirement.fromJson)
          .toList(growable: false),
    );
  }
}

class UnlockRequirement {
  const UnlockRequirement({required this.type, required this.referenceId});

  final String type;
  final String referenceId;

  factory UnlockRequirement.fromJson(JsonMap json) => UnlockRequirement(
    type: json.string('type'),
    referenceId: json.string('referenceId'),
  );
}

class RoleDefinition {
  const RoleDefinition({
    required this.id,
    required this.industry,
    required this.title,
    required this.level,
    required this.departmentIds,
    required this.requiredCompetencies,
    this.promotionTargetRoleId,
  });

  final String id;
  final String industry;
  final String title;
  final String level;
  final List<String> departmentIds;
  final List<String> requiredCompetencies;
  final String? promotionTargetRoleId;

  factory RoleDefinition.fromJson(JsonMap json) => RoleDefinition(
    id: json.string('id'),
    industry: json.string('industry'),
    title: json.string('title'),
    level: json.string('level'),
    departmentIds: json.stringList('departmentIds'),
    requiredCompetencies: json.stringList('requiredCompetencies'),
    promotionTargetRoleId: json.optionalString('promotionTargetRoleId'),
  );
}

class CompetencyDefinition {
  const CompetencyDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.observableBehaviours,
    required this.proficiencyLevels,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final List<String> observableBehaviours;
  final List<ProficiencyLevel> proficiencyLevels;

  factory CompetencyDefinition.fromJson(JsonMap json) => CompetencyDefinition(
    id: json.string('id'),
    name: json.string('name'),
    description: json.string('description'),
    category: json.string('category'),
    observableBehaviours: json.stringList('observableBehaviours'),
    proficiencyLevels: json
        .mapList('proficiencyLevels')
        .map(ProficiencyLevel.fromJson)
        .toList(growable: false),
  );
}

class ProficiencyLevel {
  const ProficiencyLevel({
    required this.level,
    required this.name,
    required this.minimumScore,
  });

  final int level;
  final String name;
  final int minimumScore;

  factory ProficiencyLevel.fromJson(JsonMap json) => ProficiencyLevel(
    level: json.integer('level'),
    name: json.string('name'),
    minimumScore: json.integer('minimumScore'),
  );
}

class MissionDefinition {
  const MissionDefinition({
    required this.id,
    required this.version,
    required this.packId,
    required this.workplaceId,
    required this.departmentId,
    required this.processId,
    required this.role,
    required this.title,
    required this.difficulty,
    required this.estimatedDurationMinutes,
    required this.missionType,
    required this.briefing,
    required this.objectives,
    required this.startingWorkstationId,
    required this.stageIds,
    required this.stages,
    required this.tasks,
    required this.resources,
    required this.scenario,
    this.scenarios = const [],
    required this.scoringRule,
    required this.criticalErrorRules,
    this.earlyCompletionRules = const [],
  });

  final String id;
  final String version;
  final String packId;
  final String workplaceId;
  final String departmentId;
  final String processId;
  final RoleDefinition role;
  final String title;
  final MissionDifficulty difficulty;
  final int estimatedDurationMinutes;
  final MissionType missionType;
  final MissionBriefing briefing;
  final List<String> objectives;
  final String startingWorkstationId;
  final List<String> stageIds;
  final List<MissionStage> stages;
  final List<SimulationTask> tasks;
  final List<SimulationResource> resources;
  final ScenarioDefinition scenario;

  /// Named alternative variation-rule sets a candidate can be started against
  /// via `startMission(scenarioId: ...)`, on top of the always-available
  /// default seeded against [scenario]. Empty for missions that don't author
  /// a catalog -- existing content is unaffected.
  final List<NamedScenario> scenarios;
  final ScoringRule scoringRule;
  final List<CriticalErrorRule> criticalErrorRules;

  /// Terminal-exception rules for scenarios where correctly stopping bad
  /// work early is itself success. Empty for missions that don't author any
  /// -- existing content and scoring are unaffected.
  final List<EarlyCompletionRule> earlyCompletionRules;

  String get versionedId => '$id@$version';

  SimulationTask task(String id) => tasks.firstWhere((item) => item.id == id);

  /// The variation-rule set to generate a scenario from: the named catalog
  /// entry if [scenarioId] is given and known, otherwise the mission's
  /// always-available default.
  ScenarioDefinition scenarioFor(String? scenarioId) {
    if (scenarioId == null) return scenario;
    final named = scenarios.firstWhere(
      (item) => item.id == scenarioId,
      orElse: () => throw FormatException('Unknown scenario id $scenarioId'),
    );
    return ScenarioDefinition(
      defaultSeed: scenario.defaultSeed,
      variationRules: named.variationRules,
    );
  }

  factory MissionDefinition.fromJson(JsonMap json) {
    final mission = MissionDefinition(
      id: json.string('id'),
      version: json.string('version'),
      packId: json.string('packId'),
      workplaceId: json.string('workplaceId'),
      departmentId: json.string('departmentId'),
      processId: json.string('processId'),
      role: RoleDefinition.fromJson(json.object('role')),
      title: json.string('title'),
      difficulty: MissionDifficulty.fromWireName(json.string('difficulty')),
      estimatedDurationMinutes: json.integer('estimatedDurationMinutes'),
      missionType: MissionType.fromWireName(json.string('missionType')),
      briefing: MissionBriefing.fromJson(json.object('briefing')),
      objectives: json.stringList('objectives'),
      startingWorkstationId: json.string('startingWorkstationId'),
      stageIds: json.stringList('stages'),
      stages: json
          .mapList('stageDefinitions')
          .map(MissionStage.fromJson)
          .toList(growable: false),
      tasks: json
          .mapList('taskDefinitions')
          .map(SimulationTask.fromJson)
          .toList(growable: false),
      resources: json
          .mapList('resources')
          .map(SimulationResource.fromJson)
          .toList(growable: false),
      scenario: ScenarioDefinition.fromJson(json.object('scenario')),
      scenarios: json['scenarios'] is List<Object?>
          ? json
                .mapList('scenarios')
                .map(NamedScenario.fromJson)
                .toList(growable: false)
          : const [],
      scoringRule: ScoringRule.fromJson(json.object('scoringRule')),
      criticalErrorRules: json
          .mapList('criticalErrorRules')
          .map(CriticalErrorRule.fromJson)
          .toList(growable: false),
      earlyCompletionRules: json['earlyCompletionRules'] is List<Object?>
          ? json
                .mapList('earlyCompletionRules')
                .map(EarlyCompletionRule.fromJson)
                .toList(growable: false)
          : const [],
    );
    mission.validateReferences();
    return mission;
  }

  void validateReferences() {
    final definedStageIds = stages.map((item) => item.id).toSet();
    final definedTaskIds = tasks.map((item) => item.id).toSet();
    final definedResourceIds = resources.map((item) => item.id).toSet();
    for (final rule in earlyCompletionRules) {
      if (!definedTaskIds.contains(rule.triggerTaskId)) {
        throw FormatException(
          'Early completion rule ${rule.id} references an undefined task',
        );
      }
    }
    if (!definedStageIds.containsAll(stageIds)) {
      throw const FormatException('Mission references an undefined stage');
    }
    for (final stage in stages) {
      if (!definedTaskIds.containsAll(stage.taskIds)) {
        throw FormatException('Stage ${stage.id} references an undefined task');
      }
    }
    for (final task in tasks) {
      if (!definedStageIds.contains(task.stageId) ||
          !definedResourceIds.containsAll(task.targetResourceIds)) {
        throw FormatException('Task ${task.id} contains an invalid reference');
      }
    }
    final weight = scoringRule.categories.fold<double>(
      0,
      (sum, item) => sum + item.weight,
    );
    if ((weight - 1).abs() > 0.0001) {
      throw const FormatException('Score category weights must total 1');
    }
    final scenarioIds = <String>{};
    for (final named in scenarios) {
      if (!scenarioIds.add(named.id)) {
        throw FormatException('Duplicate scenario id ${named.id}');
      }
      for (final rule in named.variationRules) {
        if (!definedResourceIds.containsAll(rule.eligibleTargets)) {
          throw FormatException(
            'Scenario ${named.id} references an undefined resource',
          );
        }
      }
    }
  }
}

class MissionBriefing {
  const MissionBriefing({
    required this.supervisorTitle,
    required this.message,
    required this.shiftName,
    required this.supplier,
    required this.purchaseOrderNumber,
    required this.deliveryReference,
    required this.deliveryType,
    required this.responsibilities,
    required this.workplaceRules,
    required this.rulesVersion,
  });

  final String supervisorTitle;
  final String message;
  final String shiftName;
  final String supplier;
  final String purchaseOrderNumber;
  final String deliveryReference;
  final String deliveryType;
  final List<String> responsibilities;
  final List<String> workplaceRules;
  final String rulesVersion;

  factory MissionBriefing.fromJson(JsonMap json) {
    final briefing = MissionBriefing(
      supervisorTitle: json.string('supervisorTitle'),
      message: json.string('message'),
      shiftName: json.string('shiftName'),
      supplier: json.string('supplier'),
      purchaseOrderNumber: json.string('purchaseOrderNumber'),
      deliveryReference: json.string('deliveryReference'),
      deliveryType: json.string('deliveryType'),
      responsibilities: json.stringList('responsibilities'),
      workplaceRules: json.stringList('workplaceRules'),
      rulesVersion: json.string('rulesVersion'),
    );
    if (briefing.message.trim().isEmpty ||
        briefing.responsibilities.isEmpty ||
        briefing.workplaceRules.isEmpty) {
      throw const FormatException('Mission briefing content is incomplete');
    }
    return briefing;
  }
}

class MissionStage {
  const MissionStage({
    required this.id,
    required this.missionId,
    required this.sequence,
    required this.title,
    required this.workstationId,
    required this.instructions,
    required this.taskIds,
    required this.completionMode,
  });

  final String id;
  final String missionId;
  final int sequence;
  final String title;
  final String workstationId;
  final String instructions;
  final List<String> taskIds;
  final CompletionMode completionMode;

  factory MissionStage.fromJson(JsonMap json) => MissionStage(
    id: json.string('id'),
    missionId: json.string('missionId'),
    sequence: json.integer('sequence'),
    title: json.string('title'),
    workstationId: json.string('workstationId'),
    instructions: json.string('instructions'),
    taskIds: json.stringList('taskIds'),
    completionMode: CompletionMode.fromWireName(json.string('completionMode')),
  );
}

class SimulationTask {
  const SimulationTask({
    required this.id,
    required this.stageId,
    required this.taskType,
    required this.title,
    required this.instructions,
    required this.mandatory,
    required this.repeatable,
    required this.availableActions,
    required this.targetResourceIds,
    required this.competencyMappings,
    required this.maximumPoints,
    required this.scoreCategoryId,
    required this.evaluationRules,
    this.completeOnValidAction = false,
  });

  final String id;
  final String stageId;
  final TaskType taskType;
  final String title;
  final String instructions;
  final bool mandatory;
  final bool repeatable;
  final List<ActionType> availableActions;
  final List<String> targetResourceIds;
  final List<CompetencyMapping> competencyMappings;
  final int maximumPoints;
  final String scoreCategoryId;
  final List<TaskEvaluationRule> evaluationRules;
  final bool completeOnValidAction;

  factory SimulationTask.fromJson(JsonMap json) {
    final task = SimulationTask(
      id: json.string('id'),
      stageId: json.string('stageId'),
      taskType: TaskType.fromWireName(json.string('taskType')),
      title: json.string('title'),
      instructions: json.string('instructions'),
      mandatory: json.boolean('mandatory'),
      repeatable: json.boolean('repeatable'),
      availableActions: json
          .stringList('availableActions')
          .map(ActionType.fromWireName)
          .toList(growable: false),
      targetResourceIds: json.stringList('targetResourceIds'),
      competencyMappings: json
          .mapList('competencyMappings')
          .map(CompetencyMapping.fromJson)
          .toList(growable: false),
      maximumPoints: json.integer('maximumPoints'),
      scoreCategoryId: json.string('scoreCategoryId'),
      evaluationRules: json
          .mapList('evaluationRules')
          .map(TaskEvaluationRule.fromJson)
          .toList(growable: false),
      completeOnValidAction: json.boolean('completeOnValidAction'),
    );
    final competencyWeight = task.competencyMappings.fold<double>(
      0,
      (sum, item) => sum + item.weight,
    );
    if ((competencyWeight - 1).abs() > 0.0001) {
      throw FormatException(
        'Competency weights for task ${task.id} must total 1',
      );
    }
    return task;
  }
}

class CompetencyMapping {
  const CompetencyMapping({required this.competencyId, required this.weight});

  final String competencyId;
  final double weight;

  factory CompetencyMapping.fromJson(JsonMap json) => CompetencyMapping(
    competencyId: json.string('competencyId'),
    weight: json.number('weight').toDouble(),
  );
}

class TaskEvaluationRule {
  const TaskEvaluationRule({
    required this.actionType,
    required this.outcomeType,
    required this.pointsAwarded,
    required this.feedbackCode,
    this.targetId,
    this.requiredPayload = const {},
    this.correctActionLabel,
    this.missedIssueCode,
    this.targetHasIssue,
    this.targetLacksIssue,
    this.targetMustBeCompliant = false,
    this.payloadMatchesTargetContent = const {},
  });

  final ActionType actionType;
  final String? targetId;
  final JsonMap requiredPayload;
  final OutcomeType outcomeType;
  final int pointsAwarded;
  final String feedbackCode;
  final String? correctActionLabel;
  final String? missedIssueCode;
  final String? targetHasIssue;
  final String? targetLacksIssue;
  final bool targetMustBeCompliant;
  final Map<String, String> payloadMatchesTargetContent;

  factory TaskEvaluationRule.fromJson(JsonMap json) => TaskEvaluationRule(
    actionType: ActionType.fromWireName(json.string('actionType')),
    targetId: json.optionalString('targetId'),
    requiredPayload: json['requiredPayload'] is Map<String, Object?>
        ? json.object('requiredPayload')
        : const {},
    outcomeType: OutcomeType.fromWireName(json.string('outcomeType')),
    pointsAwarded: json.integer('pointsAwarded'),
    feedbackCode: json.string('feedbackCode'),
    correctActionLabel: json.optionalString('correctActionLabel'),
    missedIssueCode: json.optionalString('missedIssueCode'),
    targetHasIssue: json.optionalString('targetHasIssue'),
    targetLacksIssue: json.optionalString('targetLacksIssue'),
    targetMustBeCompliant: json.boolean('targetMustBeCompliant'),
    payloadMatchesTargetContent:
        json['payloadMatchesTargetContent'] is Map<String, Object?>
        ? json
              .object('payloadMatchesTargetContent')
              .map((key, value) => MapEntry(key, value as String))
        : const {},
  );
}

class SimulationResource {
  const SimulationResource({
    required this.id,
    required this.missionId,
    required this.resourceType,
    required this.title,
    required this.content,
    this.issues = const [],
  });

  final String id;
  final String missionId;
  final ResourceType resourceType;
  final String title;
  final JsonMap content;
  final List<ResourceIssue> issues;

  SimulationResource copyWith({
    JsonMap? content,
    List<ResourceIssue>? issues,
  }) => SimulationResource(
    id: id,
    missionId: missionId,
    resourceType: resourceType,
    title: title,
    content: content ?? this.content,
    issues: issues ?? this.issues,
  );

  factory SimulationResource.fromJson(JsonMap json) => SimulationResource(
    id: json.string('id'),
    missionId: json.string('missionId'),
    resourceType: ResourceType.fromWireName(json.string('resourceType')),
    title: json.string('title'),
    content: json.object('content'),
    issues: (json['issues'] is List<Object?>)
        ? json.mapList('issues').map(ResourceIssue.fromJson).toList()
        : const [],
  );
}

class ResourceIssue {
  const ResourceIssue({required this.issueType, required this.severity});

  final String issueType;
  final IssueSeverity severity;

  factory ResourceIssue.fromJson(JsonMap json) => ResourceIssue(
    issueType: json.string('issueType'),
    severity: IssueSeverity.values.byName(json.string('severity')),
  );

  JsonMap toJson() => {'issueType': issueType, 'severity': severity.name};
}

class ScenarioDefinition {
  const ScenarioDefinition({
    required this.defaultSeed,
    required this.variationRules,
  });

  final int defaultSeed;
  final List<ScenarioVariationRule> variationRules;

  factory ScenarioDefinition.fromJson(JsonMap json) => ScenarioDefinition(
    defaultSeed: json.integer('defaultSeed'),
    variationRules: json
        .mapList('variationRules')
        .map(ScenarioVariationRule.fromJson)
        .toList(growable: false),
  );
}

class ScenarioVariationRule {
  const ScenarioVariationRule({
    required this.type,
    required this.issue,
    required this.severity,
    required this.eligibleTargets,
    required this.count,
  });

  final String type;
  final String issue;
  final IssueSeverity severity;
  final List<String> eligibleTargets;
  final int count;

  factory ScenarioVariationRule.fromJson(JsonMap json) => ScenarioVariationRule(
    type: json.string('type'),
    issue: json.string('issue'),
    severity: IssueSeverity.values.byName(json.string('severity')),
    eligibleTargets: json.stringList('eligibleTargets'),
    count: json.integer('count'),
  );
}

/// One entry in a mission's scenario catalog -- a named, independently
/// selectable alternative to the mission's default [ScenarioDefinition].
/// See docs/24-receiving-department-content-specification.md section 3.3.
class NamedScenario {
  const NamedScenario({
    required this.id,
    required this.name,
    required this.variationRules,
    this.pedagogicalIntent,
  });

  final String id;
  final String name;
  final List<ScenarioVariationRule> variationRules;
  final String? pedagogicalIntent;

  factory NamedScenario.fromJson(JsonMap json) => NamedScenario(
    id: json.string('id'),
    name: json.string('name'),
    variationRules: json
        .mapList('variationRules')
        .map(ScenarioVariationRule.fromJson)
        .toList(growable: false),
    pedagogicalIntent: json.optionalString('pedagogicalIntent'),
  );
}

class ScoringRule {
  const ScoringRule({
    required this.minimumScore,
    required this.allMandatoryTasksRequired,
    required this.criticalErrorsAllowed,
    required this.categories,
  });

  final int minimumScore;
  final bool allMandatoryTasksRequired;
  final int criticalErrorsAllowed;
  final List<ScoreCategory> categories;

  factory ScoringRule.fromJson(JsonMap json) => ScoringRule(
    minimumScore: json.integer('minimumScore'),
    allMandatoryTasksRequired: json.boolean('allMandatoryTasksRequired'),
    criticalErrorsAllowed: json.integer('criticalErrorsAllowed'),
    categories: json
        .mapList('scoreCategories')
        .map(ScoreCategory.fromJson)
        .toList(growable: false),
  );
}

class ScoreCategory {
  const ScoreCategory({required this.id, required this.weight});

  final String id;
  final double weight;

  factory ScoreCategory.fromJson(JsonMap json) => ScoreCategory(
    id: json.string('id'),
    weight: json.number('weight').toDouble(),
  );
}

class CriticalErrorRule {
  const CriticalErrorRule({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.actionType,
    required this.scorePenalty,
    required this.preventsPassing,
    required this.feedback,
    this.targetHasIssue,
    this.selectedDisposition,
    this.requiredPayload = const {},
  });

  final String id;
  final String title;
  final String description;
  final CriticalErrorSeverity severity;
  final ActionType actionType;
  final String? targetHasIssue;
  final DispositionType? selectedDisposition;
  final JsonMap requiredPayload;
  final int scorePenalty;
  final bool preventsPassing;
  final String feedback;

  factory CriticalErrorRule.fromJson(JsonMap json) {
    final trigger = json.object('trigger');
    return CriticalErrorRule(
      id: json.string('id'),
      title: json.string('title'),
      description: json.string('description'),
      severity: CriticalErrorSeverity.values.byName(json.string('severity')),
      actionType: ActionType.fromWireName(trigger.string('actionType')),
      targetHasIssue: trigger.optionalString('targetHasIssue'),
      selectedDisposition: trigger.optionalString('selectedDisposition') == null
          ? null
          : DispositionType.fromWireName(trigger.string('selectedDisposition')),
      requiredPayload: trigger['requiredPayload'] is Map<String, Object?>
          ? trigger.object('requiredPayload')
          : const {},
      scorePenalty: json.integer('scorePenalty'),
      preventsPassing: json.boolean('preventsPassing'),
      feedback: json.string('feedback'),
    );
  }
}

/// A content-authored rule for terminal exception scenarios where correctly
/// stopping bad work before it starts is itself the successful outcome --
/// e.g. rejecting a wrong-supplier delivery at Receiving Dock rather than
/// spending counting/inspection effort on stock that should never have been
/// accepted. Matched against a scored action outcome by
/// [MissionScoringService] before the normal mandatory-task completeness
/// check, so it never changes how any other mission or scenario is scored.
class EarlyCompletionRule {
  const EarlyCompletionRule({
    required this.id,
    required this.triggerTaskId,
    required this.triggerActionType,
    required this.requiredOutcome,
    required this.resultStatus,
    required this.completionLabel,
    required this.skipRemainingMandatoryTasks,
    required this.evidenceScope,
    this.requiredPayload = const {},
  });

  final String id;
  final String triggerTaskId;
  final ActionType triggerActionType;
  final JsonMap requiredPayload;
  final OutcomeType requiredOutcome;
  final MissionStatus resultStatus;
  final String completionLabel;
  final bool skipRemainingMandatoryTasks;
  final String evidenceScope;

  factory EarlyCompletionRule.fromJson(JsonMap json) => EarlyCompletionRule(
    id: json.string('id'),
    triggerTaskId: json.string('triggerTaskId'),
    triggerActionType: ActionType.fromWireName(
      json.string('triggerActionType'),
    ),
    requiredPayload: json['requiredPayload'] is Map<String, Object?>
        ? json.object('requiredPayload')
        : const {},
    requiredOutcome: OutcomeType.fromWireName(json.string('requiredOutcome')),
    resultStatus: MissionStatus.fromWireName(json.string('resultStatus')),
    completionLabel: json.string('completionLabel'),
    skipRemainingMandatoryTasks: json.boolean('skipRemainingMandatoryTasks'),
    evidenceScope: json.string('evidenceScope'),
  );
}

class RemediationRecommendation {
  const RemediationRecommendation({
    required this.id,
    required this.title,
    required this.contentType,
    required this.estimatedDurationMinutes,
    required this.competencyId,
    required this.triggerIssueTypes,
    required this.learningObjectives,
  });

  final String id;
  final String title;
  final String contentType;
  final int estimatedDurationMinutes;
  final String competencyId;
  final List<String> triggerIssueTypes;
  final List<String> learningObjectives;

  factory RemediationRecommendation.fromJson(JsonMap json) =>
      RemediationRecommendation(
        id: json.string('id'),
        title: json.string('title'),
        contentType: json.string('contentType'),
        estimatedDurationMinutes: json.integer('estimatedDurationMinutes'),
        competencyId: json.string('competencyId'),
        triggerIssueTypes: json
            .mapList('triggerConditions')
            .map((item) => item.string('issueType'))
            .toList(growable: false),
        learningObjectives: json.stringList('learningObjectives'),
      );
}

extension JsonMapReader on JsonMap {
  String string(String key) {
    final value = this[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Expected non-empty string at "$key"');
    }
    return value;
  }

  String? optionalString(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('Expected string at "$key"');
    return value;
  }

  int integer(String key) {
    final value = this[key];
    if (value is! int) throw FormatException('Expected integer at "$key"');
    return value;
  }

  num number(String key) {
    final value = this[key];
    if (value is! num) throw FormatException('Expected number at "$key"');
    return value;
  }

  bool boolean(String key, {bool fallback = false}) {
    final value = this[key];
    if (value == null) return fallback;
    if (value is! bool) throw FormatException('Expected boolean at "$key"');
    return value;
  }

  JsonMap object(String key) {
    final value = this[key];
    if (value is! Map<String, Object?>) {
      throw FormatException('Expected object at "$key"');
    }
    return value;
  }

  List<JsonMap> mapList(String key) {
    final value = this[key];
    if (value is! List<Object?>) {
      throw FormatException('Expected list at "$key"');
    }
    return value
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw FormatException('Expected object items at "$key"');
          }
          return item;
        })
        .toList(growable: false);
  }

  List<String> stringList(String key) {
    final value = this[key];
    if (value is! List<Object?> || value.any((item) => item is! String)) {
      throw FormatException('Expected string list at "$key"');
    }
    return value.cast<String>().toList(growable: false);
  }
}
