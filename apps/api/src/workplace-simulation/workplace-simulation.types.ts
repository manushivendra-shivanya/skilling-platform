export type JsonPrimitive = string | number | boolean | null;
export type JsonValue =
  | JsonPrimitive
  | JsonValue[]
  | { [key: string]: JsonValue };
export type JsonRecord = { [key: string]: JsonValue };

export interface WmsSyncRequest {
  attempt: WmsAttemptPayload;
  generatedScenario?: JsonRecord | null;
  result?: WmsResultPayload | null;
}

export interface WmsAttemptPayload {
  id: string;
  candidateId?: string;
  missionId: string;
  missionVersion: string;
  attemptNumber: number;
  scenarioSeed: number;
  scenarioId?: string | null;
  state: string;
  timerStatus: string;
  currentStageId?: string | null;
  completedTaskIds?: string[];
  createdAt: string;
  briefingAcknowledgedAt?: string | null;
  shiftStartedAt?: string | null;
  pausedAt?: string | null;
  timerResumedAt?: string | null;
  submittedAt?: string | null;
  completedAt?: string | null;
  elapsedSimulationSeconds?: number;
  actions?: WmsLearnerActionPayload[];
  auditEvents?: WmsAuditEventPayload[];
  documentReviewDraft?: JsonRecord | null;
  receivingCountDraft?: JsonRecord | null;
  inspectionDraft?: JsonRecord | null;
  dispositionDraft?: JsonRecord | null;
  discrepancyReportDraft?: JsonRecord | null;
}

export interface WmsLearnerActionPayload {
  id: string;
  attemptId: string;
  missionId: string;
  stageId: string;
  taskId: string;
  actionType: string;
  targetId?: string | null;
  payload: JsonRecord;
  sequenceNumber: number;
  simulationTimeSeconds: number;
  createdAt: string;
  isTechnical?: boolean;
}

export interface WmsAuditEventPayload {
  id: string;
  attemptId: string;
  missionId?: string;
  missionVersion?: string;
  eventType: string;
  screenId: string;
  targetId?: string | null;
  sequenceNumber: number;
  simulationElapsedSeconds: number;
  occurredAt: string;
  payload?: JsonRecord;
}

export interface WmsResultPayload {
  attemptId: string;
  missionId: string;
  missionVersion: string;
  scenarioSeed: number;
  status: string;
  overallScore: number;
  categoryScores: JsonRecord;
  competencyScores: JsonRecord[];
  mandatoryTasksCompleted: boolean;
  criticalErrors: JsonRecord[];
  correctActions: string[];
  missedIssues: string[];
  evidence?: WmsEvidencePayload[];
  recommendedRemediationIds: string[];
  completedAt: string;
}

export interface WmsEvidencePayload {
  id: string;
  candidateId?: string;
  attemptId: string;
  missionId: string;
  missionVersion: string;
  scenarioSeed: number;
  competencyId: string;
  score: number;
  evidenceType: string;
  title: string;
  description: string;
  issuedAt: string;
  verificationStatus: string;
}

export interface WmsSyncSummary {
  attemptId: string;
  actionCount: number;
  auditEventCount: number;
  resultSynced: boolean;
  evidenceCount: number;
}
