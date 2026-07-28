enum MissionState {
  notStarted('not_started'),
  briefing('briefing'),
  inProgress('in_progress'),
  paused('paused'),
  submitted('submitted'),
  evaluated('evaluated'),
  completed('completed'),
  failed('failed');

  const MissionState(this.wireName);
  final String wireName;

  static MissionState fromWireName(String value) =>
      values.firstWhere((item) => item.wireName == value);
}

enum MissionStatus {
  passed('passed'),
  retryRecommended('retry_recommended'),
  criticalFailure('critical_failure'),
  incomplete('incomplete');

  const MissionStatus(this.wireName);
  final String wireName;

  static MissionStatus fromWireName(String value) =>
      values.firstWhere((item) => item.wireName == value);
}

enum MissionDifficulty {
  beginner,
  intermediate,
  advanced;

  static MissionDifficulty fromWireName(String value) =>
      values.firstWhere((item) => item.name == value);
}

enum MissionType {
  guidedShift('guided_shift'),
  assessment('assessment');

  const MissionType(this.wireName);
  final String wireName;

  static MissionType fromWireName(String value) =>
      values.firstWhere((item) => item.wireName == value);
}

enum CompletionMode {
  allMandatoryTasks('all_mandatory_tasks'),
  minimumTaskCount('minimum_task_count'),
  correctDecision('correct_decision'),
  scoreThreshold('score_threshold'),
  eventResolved('event_resolved');

  const CompletionMode(this.wireName);
  final String wireName;

  static CompletionMode fromWireName(String value) =>
      values.firstWhere((item) => item.wireName == value);
}

enum TaskType {
  readDocument('read_document'),
  documentComparison('document_comparison'),
  inspectItem('inspect_item'),
  countQuantity('count_quantity'),
  scanBarcode('scan_barcode'),
  classifyIssue('classify_issue'),
  selectDisposition('select_disposition'),
  moveItem('move_item'),
  completeForm('complete_form'),
  makeDecision('make_decision'),
  confirmAction('confirm_action');

  const TaskType(this.wireName);
  final String wireName;

  static TaskType fromWireName(String value) =>
      values.firstWhere((item) => item.wireName == value);
}

enum ResourceType {
  document('document'),
  inventoryItem('inventory_item'),
  carton('carton'),
  equipment('equipment'),
  form('form'),
  policy('policy'),
  message('message'),
  workOrder('work_order'),
  customerRecord('customer_record'),
  transaction('transaction');

  const ResourceType(this.wireName);
  final String wireName;

  static ResourceType fromWireName(String value) =>
      values.firstWhere((item) => item.wireName == value);
}

enum ActionType {
  openResource('open_resource'),
  markMatch('mark_match'),
  markShortage('mark_shortage'),
  markExcess('mark_excess'),
  addNote('add_note'),
  inspectItem('inspect_item'),
  recordIssue('record_issue'),
  scanBarcode('scan_barcode'),
  countQuantity('count_quantity'),
  selectDisposition('select_disposition'),
  moveItem('move_item'),
  completeForm('complete_form'),
  makeDecision('make_decision'),
  confirmAction('confirm_action'),
  technicalFailure('technical_failure');

  const ActionType(this.wireName);
  final String wireName;

  static ActionType fromWireName(String value) =>
      values.firstWhere((item) => item.wireName == value);
}

enum OutcomeType {
  correct('correct'),
  partiallyCorrect('partially_correct'),
  incorrect('incorrect'),
  unsafe('unsafe'),
  nonCompliant('non_compliant'),
  incomplete('incomplete'),
  notApplicable('not_applicable');

  const OutcomeType(this.wireName);
  final String wireName;

  static OutcomeType fromWireName(String value) =>
      values.firstWhere((item) => item.wireName == value);
}

enum IssueSeverity { minor, major, critical }

enum DispositionType {
  accept('accept'),
  quarantine('quarantine'),
  holdForVerification('hold_for_verification'),
  rejectReturn('reject_return'),
  escalate('escalate');

  const DispositionType(this.wireName);
  final String wireName;

  static DispositionType fromWireName(String value) =>
      values.firstWhere((item) => item.wireName == value);
}

enum CriticalErrorSeverity { minor, major, critical }

enum EvidenceType {
  simulationObservation('simulation_observation');

  const EvidenceType(this.wireName);
  final String wireName;
}
