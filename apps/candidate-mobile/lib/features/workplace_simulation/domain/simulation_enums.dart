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

enum SimulationTimerStatus {
  notStarted('not_started'),
  running('running'),
  paused('paused'),
  stopped('stopped');

  const SimulationTimerStatus(this.wireName);
  final String wireName;

  static SimulationTimerStatus fromWireName(String value) =>
      values.firstWhere((item) => item.wireName == value);
}

enum AttemptAuditEventType {
  simulationEntryOpened,
  missionSelected,
  attemptCreated,
  attemptResumeRequested,
  attemptResumed,
  retryRequested,
  retryAttemptCreated,
  entryLoadFailed,
  briefingOpened,
  missionDetailsOpened,
  briefingAcknowledged,
  briefingAcknowledgementRemoved,
  shiftStartRequested,
  shiftStarted,
  shiftStartRejected,
  shiftStartFailed,
  attemptPaused,
  attemptResumedFromPause,
  workplaceOverviewOpened,
  workstationSelected,
  workstationOpenRejected,
  workstationOpened,
  lockedWorkstationSelected,
  recommendedActionSelected,
  pauseRequested,
  resumeRequested,
  saveAndExitRequested,
  shiftPaused,
  shiftResumed,
  shiftExited,
  workplaceLoadFailed,
  documentDeskOpened,
  documentRowSelected,
  documentFindingEditorOpened,
  documentFindingRemoved,
  documentFindingsSaveRequested,
  documentFindingsSaved,
  documentFindingsSaveFailed,
  documentReviewDraftSaved,
  documentDeskExited,
  receivingDockOpened,
  deliveryIdentityEditorOpened,
  cartonCountEditorOpened,
  cartonCountEdited,
  cartonCountSaveRequested,
  receivingCountSubmissionRequested,
  receivingCountSaved,
  receivingCountSaveFailed,
  receivingCountDraftSaved,
  receivingDockExited,
  inspectionZoneOpened,
  cartonInspectionEditorOpened,
  cartonInspectionEdited,
  barcodeScanEditorOpened,
  barcodeScanEdited,
  inspectionSubmissionRequested,
  inspectionSaved,
  inspectionSaveFailed,
  inspectionDraftSaved,
  inspectionZoneExited,
  quarantineZoneOpened,
  quarantineZoneExited,
  dispositionEditorOpened,
  dispositionEdited,
  dispositionsSubmissionRequested,
  dispositionsSaved,
  dispositionsSaveFailed,
  dispositionsDraftSaved,
  quarantineConfirmed,
  quarantineConfirmationFailed,
  releaseDecisionEditorOpened,
  releaseDecisionEdited,
  releaseDecisionsSubmissionRequested,
  releaseDecisionsSaved,
  releaseDecisionsSaveFailed,
  releaseDecisionsDraftSaved,
  receivingOfficeOpened,
  receivingOfficeExited,
  discrepancyReportFlagsSaved,
  discrepancyReportSubmissionRequested,
  discrepancyReportSaved,
  discrepancyReportSaveFailed,
  receivingDecisionSelected,
  receivingDecisionFailed,
  supervisorNotificationRequested,
  supervisorNotified,
  supervisorNotificationFailed,
  missionSubmitted,
  missionSubmissionFailed,
  performanceFeedbackOpened,
  screenLoadFailed,
  attemptExited,
  workstationScreenOpened,
  workstationScreenExited;

  static AttemptAuditEventType fromWireName(String value) {
    final normalized = value.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (match) => match.group(1)!.toUpperCase(),
    );
    return values.firstWhere((item) => item.name == normalized);
  }
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
  requestApproval('request_approval'),
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
  transaction('transaction'),
  person('person');

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
  classifyIssue('classify_issue'),
  documentFindingAdded('document_finding_added'),
  documentFindingUpdated('document_finding_updated'),
  documentFindingRemoved('document_finding_removed'),
  documentReviewSubmitted('document_review_submitted'),
  inspectItem('inspect_item'),
  recordIssue('record_issue'),
  scanBarcode('scan_barcode'),
  countQuantity('count_quantity'),
  shipmentIdentityConfirmed('shipment_identity_confirmed'),
  cartonCountRecorded('carton_count_recorded'),
  cartonCountUpdated('carton_count_updated'),
  cartonCountRemoved('carton_count_removed'),
  countMethodSelected('count_method_selected'),
  receivingCountSubmitted('receiving_count_submitted'),
  cartonInspectionRecorded('carton_inspection_recorded'),
  cartonInspectionUpdated('carton_inspection_updated'),
  cartonInspectionRemoved('carton_inspection_removed'),
  barcodeScanRecorded('barcode_scan_recorded'),
  barcodeScanUpdated('barcode_scan_updated'),
  barcodeScanRemoved('barcode_scan_removed'),
  selectDisposition('select_disposition'),
  dispositionRecorded('disposition_recorded'),
  dispositionUpdated('disposition_updated'),
  dispositionRemoved('disposition_removed'),
  selectReleaseDecision('select_release_decision'),
  releaseDecisionRecorded('release_decision_recorded'),
  releaseDecisionUpdated('release_decision_updated'),
  releaseDecisionRemoved('release_decision_removed'),
  moveItem('move_item'),
  completeForm('complete_form'),
  makeDecision('make_decision'),
  confirmAction('confirm_action'),
  speak('speak'),
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

enum ReceivingDecisionOutcome {
  accept('accept'),
  partiallyAccept('partially_accept'),
  reject('reject');

  const ReceivingDecisionOutcome(this.wireName);
  final String wireName;

  static ReceivingDecisionOutcome fromWireName(String value) =>
      values.firstWhere((item) => item.wireName == value);
}

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

/// The candidate's recommendation for stock still sitting in quarantine or
/// on hold, submitted as a supervisor-approval request rather than acted on
/// unilaterally -- an associate may quarantine or hold stock on their own
/// judgment, but releasing it back to available inventory is the one
/// decision this mission's workplace rules reserve for supervisor sign-off.
enum ReleaseDecision {
  releaseToStock('release_to_stock'),
  continueHold('continue_hold'),
  returnToSupplier('return_to_supplier'),
  disposeOnSite('dispose_on_site'),

  /// System-recorded only, never a candidate choice -- submitted
  /// automatically for cartons that were never quarantined or held (e.g.
  /// accepted, or rejected/escalated through a different path), so the
  /// mission's progress tracking has a real, scored action for every
  /// carton without asking the candidate to "recommend" something for
  /// stock that was never on hold in the first place.
  notApplicable('not_applicable');

  const ReleaseDecision(this.wireName);
  final String wireName;

  static ReleaseDecision fromWireName(String value) =>
      values.firstWhere((item) => item.wireName == value);
}

enum CriticalErrorSeverity { minor, major, critical }

enum EvidenceType {
  simulationObservation('simulation_observation');

  const EvidenceType(this.wireName);
  final String wireName;
}
