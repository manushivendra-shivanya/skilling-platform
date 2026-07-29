import '../domain/simulation_enums.dart';
import '../domain/workplace_task_drafts.dart';

@Deprecated('Use typed Screen 04 command results')
enum WorkplaceCommandResult {
  success,
  invalidState,
  locked,
  validationFailure,
  persistenceFailure,
}

@Deprecated('Use DocumentFinding from workplace_task_drafts.dart')
enum LegacyDocumentFindingType {
  quantityMismatch,
  unexpectedSku,
  missingSku,
  productMismatch,
  noDiscrepancy,
}

@Deprecated('Use DocumentFinding from workplace_task_drafts.dart')
class LegacyDocumentFinding {
  const LegacyDocumentFinding({
    required this.sku,
    required this.type,
    this.note,
  });

  final String sku;
  final LegacyDocumentFindingType type;
  final String? note;
}

enum DeliveryIdentityConclusion {
  matchesExpectedDelivery,
  doesNotMatchExpectedDelivery,
}

@Deprecated('Use ReceivingCountEntry and typed commands')
class ReceivingCount {
  const ReceivingCount({
    required this.cartonId,
    required this.physicalQuantity,
    required this.method,
    this.unusualCountConfirmed = false,
  });

  final String cartonId;
  final int physicalQuantity;
  final CountMethod method;
  final bool unusualCountConfirmed;
}

enum WorkstationStatus {
  locked,
  available,
  inProgress,
  completed,
  attentionRequired,
}

class WorkstationViewModel {
  const WorkstationViewModel({
    required this.workstationId,
    required this.name,
    required this.description,
    required this.iconKey,
    required this.route,
    required this.status,
    required this.isRecommended,
    required this.progressLabel,
    required this.supportingText,
  });

  final String workstationId;
  final String name;
  final String description;
  final String iconKey;
  final String? route;
  final WorkstationStatus status;
  final bool isRecommended;
  final String progressLabel;
  final String supportingText;
}

class WorkplaceOverviewViewModel {
  const WorkplaceOverviewViewModel({
    required this.attemptId,
    required this.missionId,
    required this.missionTitle,
    required this.workplaceName,
    required this.departmentName,
    required this.elapsedSimulationDuration,
    required this.timerStatus,
    required this.missionProgress,
    required this.completedStageCount,
    required this.totalStageCount,
    required this.recommendedWorkstationId,
    required this.workstations,
    required this.canPause,
    required this.canResume,
    required this.canSaveAndExit,
  });

  final String attemptId;
  final String missionId;
  final String missionTitle;
  final String workplaceName;
  final String departmentName;
  final Duration elapsedSimulationDuration;
  final SimulationTimerStatus timerStatus;
  final double missionProgress;
  final int completedStageCount;
  final int totalStageCount;
  final String? recommendedWorkstationId;
  final List<WorkstationViewModel> workstations;
  final bool canPause;
  final bool canResume;
  final bool canSaveAndExit;
}

enum OpenWorkstationResult {
  success,
  workstationLocked,
  invalidAttemptState,
  routeUnavailable,
  persistenceFailure,
}

enum SaveAndExitResult { success, invalidAttemptState, persistenceFailure }

class AddDocumentFindingCommand {
  const AddDocumentFindingCommand({
    required this.sourceDocument,
    required this.itemReference,
    required this.findingType,
    this.learnerNotes = '',
  });

  final DocumentSource sourceDocument;
  final String itemReference;
  final DocumentFindingType findingType;
  final String learnerNotes;
}

class UpdateDocumentFindingCommand {
  const UpdateDocumentFindingCommand({
    required this.findingId,
    required this.sourceDocument,
    required this.itemReference,
    required this.findingType,
    this.learnerNotes = '',
  });

  final String findingId;
  final DocumentSource sourceDocument;
  final String itemReference;
  final DocumentFindingType findingType;
  final String learnerNotes;
}

class RemoveDocumentFindingCommand {
  const RemoveDocumentFindingCommand(this.findingId);

  final String findingId;
}

class SaveDocumentReviewDraftCommand {
  const SaveDocumentReviewDraftCommand();
}

class SubmitDocumentReviewCommand {
  const SubmitDocumentReviewCommand();
}

enum AddDocumentFindingResult {
  success,
  validationFailed,
  duplicateFinding,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

enum UpdateDocumentFindingResult {
  success,
  findingNotFound,
  validationFailed,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

enum RemoveDocumentFindingResult {
  success,
  findingNotFound,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

enum SaveDocumentReviewDraftResult {
  success,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

enum SubmitDocumentReviewResult {
  success,
  noFindings,
  validationFailed,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

class ConfirmShipmentIdentityCommand {
  const ConfirmShipmentIdentityCommand({required this.confirmed});

  final bool confirmed;
}

class RecordCartonCountCommand {
  const RecordCartonCountCommand({
    required this.cartonId,
    required this.enteredQuantity,
    required this.countMethod,
    this.learnerNotes = '',
  });

  final String cartonId;
  final int enteredQuantity;
  final CountMethod countMethod;
  final String learnerNotes;
}

class UpdateCartonCountCommand {
  const UpdateCartonCountCommand({
    required this.entryId,
    required this.enteredQuantity,
    required this.countMethod,
    this.learnerNotes = '',
  });

  final String entryId;
  final int enteredQuantity;
  final CountMethod countMethod;
  final String learnerNotes;
}

class RemoveCartonCountCommand {
  const RemoveCartonCountCommand(this.entryId);

  final String entryId;
}

class SaveReceivingCountDraftCommand {
  const SaveReceivingCountDraftCommand();
}

class SubmitReceivingCountCommand {
  const SubmitReceivingCountCommand();
}

enum ConfirmShipmentIdentityResult {
  success,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

enum RecordCartonCountResult {
  success,
  invalidQuantity,
  cartonNotFound,
  duplicateEntry,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

enum UpdateCartonCountResult {
  success,
  entryNotFound,
  invalidQuantity,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

enum RemoveCartonCountResult {
  success,
  entryNotFound,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

enum SaveReceivingCountDraftResult {
  success,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

enum SubmitReceivingCountResult {
  success,
  shipmentNotConfirmed,
  incompleteCounts,
  validationFailed,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

class RecordCartonInspectionCommand {
  const RecordCartonInspectionCommand({
    required this.cartonId,
    required this.finding,
    this.learnerNotes = '',
  });

  final String cartonId;
  final CartonFinding finding;
  final String learnerNotes;
}

class UpdateCartonInspectionCommand {
  const UpdateCartonInspectionCommand({
    required this.entryId,
    required this.finding,
    this.learnerNotes = '',
  });

  final String entryId;
  final CartonFinding finding;
  final String learnerNotes;
}

class RemoveCartonInspectionCommand {
  const RemoveCartonInspectionCommand(this.entryId);

  final String entryId;
}

class RecordBarcodeScanCommand {
  const RecordBarcodeScanCommand({
    required this.cartonId,
    required this.status,
  });

  final String cartonId;
  final BarcodeStatus status;
}

class UpdateBarcodeScanCommand {
  const UpdateBarcodeScanCommand({required this.entryId, required this.status});

  final String entryId;
  final BarcodeStatus status;
}

class RemoveBarcodeScanCommand {
  const RemoveBarcodeScanCommand(this.entryId);

  final String entryId;
}

class SaveInspectionDraftCommand {
  const SaveInspectionDraftCommand();
}

class SubmitInspectionCommand {
  const SubmitInspectionCommand();
}

enum RecordCartonInspectionResult {
  success,
  cartonNotFound,
  duplicateEntry,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

enum UpdateCartonInspectionResult {
  success,
  entryNotFound,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

enum RemoveCartonInspectionResult {
  success,
  entryNotFound,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

enum RecordBarcodeScanResult {
  success,
  cartonNotFound,
  duplicateEntry,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

enum UpdateBarcodeScanResult {
  success,
  entryNotFound,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

enum RemoveBarcodeScanResult {
  success,
  entryNotFound,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

enum SaveInspectionDraftResult {
  success,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}

enum SubmitInspectionResult {
  success,
  incompleteInspection,
  incompleteScans,
  alreadySubmitted,
  invalidAttemptState,
  persistenceFailure,
}
