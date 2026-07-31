import { Injectable } from '@nestjs/common';
import { AppError } from '../common/app-error';
import { SupabaseService } from '../supabase/supabase.service';
import {
  JsonRecord,
  WmsAttemptPayload,
  WmsAuditEventPayload,
  WmsEvidencePayload,
  WmsLearnerActionPayload,
  WmsResultPayload,
  WmsSyncRequest,
  WmsSyncSummary,
} from './workplace-simulation.types';

const VALID_ATTEMPT_STATES = new Set([
  'not_started',
  'briefing',
  'in_progress',
  'paused',
  'submitted',
  'evaluated',
  'completed',
  'failed',
]);

const VALID_TIMER_STATUSES = new Set([
  'not_started',
  'running',
  'paused',
  'stopped',
]);

const VALID_RESULT_STATUSES = new Set([
  'passed',
  'retry_recommended',
  'critical_failure',
  'incomplete',
]);

@Injectable()
export class WorkplaceSimulationService {
  constructor(private readonly supabase: SupabaseService) {}

  async syncAttempt(
    candidateId: string,
    attemptId: string,
    request: WmsSyncRequest,
  ): Promise<WmsSyncSummary> {
    this.validateRequest(candidateId, attemptId, request);

    const attempt = request.attempt;
    await this.upsertAttempt(candidateId, attempt, request.generatedScenario);
    await this.insertLearnerActions(candidateId, attempt);
    await this.insertAuditEvents(candidateId, attempt);

    const result = request.result;
    if (result) {
      await this.upsertResult(candidateId, result);
      await this.insertEvidence(candidateId, result.evidence ?? []);
    }

    return {
      attemptId,
      actionCount: attempt.actions?.length ?? 0,
      auditEventCount: attempt.auditEvents?.length ?? 0,
      resultSynced: result != null,
      evidenceCount: result?.evidence?.length ?? 0,
    };
  }

  private async upsertAttempt(
    candidateId: string,
    attempt: WmsAttemptPayload,
    generatedScenario?: JsonRecord | null,
  ) {
    const row = {
      id: attempt.id,
      candidate_id: candidateId,
      mission_id: attempt.missionId,
      mission_version: attempt.missionVersion,
      attempt_number: attempt.attemptNumber,
      scenario_seed: attempt.scenarioSeed,
      scenario_id: attempt.scenarioId ?? null,
      state: attempt.state,
      timer_status: attempt.timerStatus,
      current_stage_id: attempt.currentStageId ?? null,
      completed_task_ids: attempt.completedTaskIds ?? [],
      created_at: attempt.createdAt,
      briefing_acknowledged_at: attempt.briefingAcknowledgedAt ?? null,
      shift_started_at: attempt.shiftStartedAt ?? null,
      paused_at: attempt.pausedAt ?? null,
      timer_resumed_at: attempt.timerResumedAt ?? null,
      submitted_at: attempt.submittedAt ?? null,
      completed_at: attempt.completedAt ?? null,
      elapsed_simulation_seconds: attempt.elapsedSimulationSeconds ?? 0,
      generated_scenario: generatedScenario ?? null,
      drafts: this.draftsJson(attempt),
      updated_at: new Date().toISOString(),
    };

    const { error } = await this.supabase.admin
      .from('wms_attempts')
      .upsert(row, { onConflict: 'id' });
    if (error) {
      throw new Error(`Failed to sync WMS attempt: ${error.message}`);
    }
  }

  private async insertLearnerActions(
    candidateId: string,
    attempt: WmsAttemptPayload,
  ) {
    const actions = attempt.actions ?? [];
    if (actions.length === 0) return;

    const rows = actions.map((action) => ({
      id: action.id,
      attempt_id: attempt.id,
      candidate_id: candidateId,
      mission_id: action.missionId,
      mission_version: attempt.missionVersion,
      stage_id: action.stageId,
      task_id: action.taskId,
      action_type: action.actionType,
      target_id: action.targetId ?? null,
      payload: action.payload,
      sequence_number: action.sequenceNumber,
      simulation_time_seconds: action.simulationTimeSeconds,
      created_at: action.createdAt,
      is_technical: false,
    }));

    const { error } = await this.supabase.admin
      .from('wms_learner_actions')
      .upsert(rows, { onConflict: 'id', ignoreDuplicates: true });
    if (error) {
      throw new Error(`Failed to sync WMS learner actions: ${error.message}`);
    }
  }

  private async insertAuditEvents(
    candidateId: string,
    attempt: WmsAttemptPayload,
  ) {
    const events = attempt.auditEvents ?? [];
    if (events.length === 0) return;

    const rows = events.map((event) => ({
      id: event.id,
      attempt_id: attempt.id,
      candidate_id: candidateId,
      mission_id: event.missionId ?? attempt.missionId,
      mission_version: event.missionVersion ?? attempt.missionVersion,
      screen_id: event.screenId,
      event_type: event.eventType,
      target_id: event.targetId ?? null,
      sequence_number: event.sequenceNumber,
      simulation_elapsed_seconds: event.simulationElapsedSeconds,
      occurred_at: event.occurredAt,
      payload: event.payload ?? {},
    }));

    const { error } = await this.supabase.admin
      .from('wms_attempt_audit_events')
      .upsert(rows, { onConflict: 'id', ignoreDuplicates: true });
    if (error) {
      throw new Error(`Failed to sync WMS audit events: ${error.message}`);
    }
  }

  private async upsertResult(candidateId: string, result: WmsResultPayload) {
    const row = {
      attempt_id: result.attemptId,
      candidate_id: candidateId,
      mission_id: result.missionId,
      mission_version: result.missionVersion,
      scenario_seed: result.scenarioSeed,
      status: result.status,
      overall_score: result.overallScore,
      category_scores: result.categoryScores,
      competency_scores: result.competencyScores,
      mandatory_tasks_completed: result.mandatoryTasksCompleted,
      critical_errors: result.criticalErrors,
      correct_actions: result.correctActions,
      missed_issues: result.missedIssues,
      recommended_remediation_ids: result.recommendedRemediationIds,
      result,
      completed_at: result.completedAt,
    };

    const { error } = await this.supabase.admin
      .from('wms_attempt_results')
      .upsert(row, { onConflict: 'attempt_id' });
    if (error) {
      throw new Error(`Failed to sync WMS result: ${error.message}`);
    }
  }

  private async insertEvidence(
    candidateId: string,
    evidence: WmsEvidencePayload[],
  ) {
    if (evidence.length === 0) return;

    const rows = evidence.map((item) => ({
      id: item.id,
      attempt_id: item.attemptId,
      candidate_id: candidateId,
      mission_id: item.missionId,
      mission_version: item.missionVersion,
      scenario_seed: item.scenarioSeed,
      competency_id: item.competencyId,
      score: item.score,
      evidence_type: item.evidenceType,
      title: item.title,
      description: item.description,
      verification_status: item.verificationStatus,
      evidence: item,
      issued_at: item.issuedAt,
    }));

    const { error } = await this.supabase.admin
      .from('wms_competency_evidence')
      .upsert(rows, { onConflict: 'id', ignoreDuplicates: true });
    if (error) {
      throw new Error(`Failed to sync WMS evidence: ${error.message}`);
    }
  }

  private draftsJson(attempt: WmsAttemptPayload): JsonRecord {
    return {
      documentReviewDraft: attempt.documentReviewDraft ?? null,
      receivingCountDraft: attempt.receivingCountDraft ?? null,
      inspectionDraft: attempt.inspectionDraft ?? null,
      dispositionDraft: attempt.dispositionDraft ?? null,
      discrepancyReportDraft: attempt.discrepancyReportDraft ?? null,
    };
  }

  private validateRequest(
    candidateId: string,
    attemptId: string,
    request: WmsSyncRequest,
  ) {
    if (!request || typeof request !== 'object') {
      throw AppError.validation('A WMS sync payload is required.');
    }
    const attempt = request.attempt;
    if (!attempt) {
      throw AppError.validation('A WMS attempt payload is required.');
    }
    if (attempt.id !== attemptId) {
      throw AppError.validation('Attempt id does not match the route.');
    }
    if (attempt.candidateId && attempt.candidateId !== candidateId) {
      throw AppError.validation('Attempt candidate does not match session.');
    }
    this.requiredString(attempt.id, 'attempt.id');
    this.requiredString(attempt.missionId, 'attempt.missionId');
    this.requiredString(attempt.missionVersion, 'attempt.missionVersion');
    this.requiredPositiveInteger(attempt.attemptNumber, 'attempt.attemptNumber');
    this.requiredNonNegativeInteger(attempt.scenarioSeed, 'attempt.scenarioSeed');
    if (!VALID_ATTEMPT_STATES.has(attempt.state)) {
      throw AppError.validation('Unsupported WMS attempt state.', {
        state: attempt.state,
      });
    }
    if (!VALID_TIMER_STATUSES.has(attempt.timerStatus)) {
      throw AppError.validation('Unsupported WMS timer status.', {
        timerStatus: attempt.timerStatus,
      });
    }
    this.requiredIsoDate(attempt.createdAt, 'attempt.createdAt');
    this.optionalIsoDate(
      attempt.briefingAcknowledgedAt,
      'attempt.briefingAcknowledgedAt',
    );
    this.optionalIsoDate(attempt.shiftStartedAt, 'attempt.shiftStartedAt');
    this.optionalIsoDate(attempt.pausedAt, 'attempt.pausedAt');
    this.optionalIsoDate(attempt.timerResumedAt, 'attempt.timerResumedAt');
    this.optionalIsoDate(attempt.submittedAt, 'attempt.submittedAt');
    this.optionalIsoDate(attempt.completedAt, 'attempt.completedAt');
    this.requiredNonNegativeInteger(
      attempt.elapsedSimulationSeconds ?? 0,
      'attempt.elapsedSimulationSeconds',
    );
    this.validateActions(attempt.id, attempt.actions ?? []);
    this.validateAuditEvents(attempt.id, attempt.auditEvents ?? []);
    if (request.result) {
      this.validateResult(candidateId, attempt.id, request.result);
    }
  }

  private validateActions(
    attemptId: string,
    actions: WmsLearnerActionPayload[],
  ) {
    const sequences = new Set<number>();
    for (const action of actions) {
      this.requiredString(action.id, 'action.id');
      if (action.attemptId !== attemptId) {
        throw AppError.validation('Learner action attempt mismatch.', {
          actionId: action.id,
        });
      }
      if (action.isTechnical) {
        throw AppError.validation(
          'Technical events must be synced as audit events, not learner actions.',
          { actionId: action.id },
        );
      }
      this.requiredString(action.missionId, 'action.missionId');
      this.requiredString(action.stageId, 'action.stageId');
      this.requiredString(action.taskId, 'action.taskId');
      this.requiredString(action.actionType, 'action.actionType');
      this.requiredPositiveInteger(
        action.sequenceNumber,
        'action.sequenceNumber',
      );
      this.requiredNonNegativeInteger(
        action.simulationTimeSeconds,
        'action.simulationTimeSeconds',
      );
      this.requiredIsoDate(action.createdAt, 'action.createdAt');
      this.ensureUniqueSequence(sequences, action.sequenceNumber, 'action');
    }
  }

  private validateAuditEvents(
    attemptId: string,
    events: WmsAuditEventPayload[],
  ) {
    const sequences = new Set<number>();
    for (const event of events) {
      this.requiredString(event.id, 'auditEvent.id');
      if (event.attemptId !== attemptId) {
        throw AppError.validation('Audit event attempt mismatch.', {
          eventId: event.id,
        });
      }
      this.requiredString(event.eventType, 'auditEvent.eventType');
      this.requiredString(event.screenId, 'auditEvent.screenId');
      this.requiredPositiveInteger(
        event.sequenceNumber,
        'auditEvent.sequenceNumber',
      );
      this.requiredNonNegativeInteger(
        event.simulationElapsedSeconds,
        'auditEvent.simulationElapsedSeconds',
      );
      this.requiredIsoDate(event.occurredAt, 'auditEvent.occurredAt');
      this.ensureUniqueSequence(sequences, event.sequenceNumber, 'auditEvent');
    }
  }

  private validateResult(
    candidateId: string,
    attemptId: string,
    result: WmsResultPayload,
  ) {
    if (result.attemptId !== attemptId) {
      throw AppError.validation('Result attempt mismatch.');
    }
    this.requiredString(result.missionId, 'result.missionId');
    this.requiredString(result.missionVersion, 'result.missionVersion');
    this.requiredNonNegativeInteger(result.scenarioSeed, 'result.scenarioSeed');
    if (!VALID_RESULT_STATUSES.has(result.status)) {
      throw AppError.validation('Unsupported WMS result status.', {
        status: result.status,
      });
    }
    if (result.overallScore < 0 || result.overallScore > 100) {
      throw AppError.validation('Result score must be between 0 and 100.');
    }
    this.requiredIsoDate(result.completedAt, 'result.completedAt');
    for (const item of result.evidence ?? []) {
      if (item.candidateId && item.candidateId !== candidateId) {
        throw AppError.validation('Evidence candidate does not match session.', {
          evidenceId: item.id,
        });
      }
      if (item.attemptId !== attemptId) {
        throw AppError.validation('Evidence attempt mismatch.', {
          evidenceId: item.id,
        });
      }
      this.requiredString(item.id, 'evidence.id');
      this.requiredString(item.competencyId, 'evidence.competencyId');
      if (item.score < 0 || item.score > 100) {
        throw AppError.validation('Evidence score must be between 0 and 100.', {
          evidenceId: item.id,
        });
      }
      this.requiredIsoDate(item.issuedAt, 'evidence.issuedAt');
    }
  }

  private requiredString(value: unknown, field: string) {
    if (typeof value !== 'string' || value.trim() === '') {
      throw AppError.validation(`${field} is required.`);
    }
  }

  private requiredPositiveInteger(value: unknown, field: string) {
    if (!Number.isInteger(value) || Number(value) <= 0) {
      throw AppError.validation(`${field} must be a positive integer.`);
    }
  }

  private requiredNonNegativeInteger(value: unknown, field: string) {
    if (!Number.isInteger(value) || Number(value) < 0) {
      throw AppError.validation(`${field} must be a non-negative integer.`);
    }
  }

  private requiredIsoDate(value: unknown, field: string) {
    if (typeof value !== 'string' || Number.isNaN(Date.parse(value))) {
      throw AppError.validation(`${field} must be an ISO timestamp.`);
    }
  }

  private optionalIsoDate(value: unknown, field: string) {
    if (value == null) return;
    this.requiredIsoDate(value, field);
  }

  private ensureUniqueSequence(
    sequences: Set<number>,
    sequenceNumber: number,
    label: string,
  ) {
    if (sequences.has(sequenceNumber)) {
      throw AppError.validation(`Duplicate ${label} sequence number.`, {
        sequenceNumber,
      });
    }
    sequences.add(sequenceNumber);
  }
}
