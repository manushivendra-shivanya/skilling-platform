import { AppError } from '../common/app-error';
import { SupabaseService } from '../supabase/supabase.service';
import { WorkplaceSimulationService } from './workplace-simulation.service';
import { WmsSyncRequest } from './workplace-simulation.types';

type TableName =
  | 'wms_attempts'
  | 'wms_learner_actions'
  | 'wms_attempt_audit_events'
  | 'wms_attempt_results'
  | 'wms_competency_evidence';

type Row = Record<string, unknown>;

class FakeSupabaseAdmin {
  rows: Record<TableName, Row[]> = {
    wms_attempts: [],
    wms_learner_actions: [],
    wms_attempt_audit_events: [],
    wms_attempt_results: [],
    wms_competency_evidence: [],
  };

  from(table: TableName) {
    return {
      upsert: async (
        input: Row | Row[],
        options?: { onConflict?: string; ignoreDuplicates?: boolean },
      ) => {
        const values = Array.isArray(input) ? input : [input];
        for (const row of values) {
          this.upsertRow(table, row, options);
        }
        return { error: null };
      },
    };
  }

  private upsertRow(
    table: TableName,
    row: Row,
    options?: { onConflict?: string; ignoreDuplicates?: boolean },
  ) {
    const conflictKey = options?.onConflict ?? 'id';
    const existingIndex = this.rows[table].findIndex(
      (item) => item[conflictKey] === row[conflictKey],
    );
    if (existingIndex === -1) {
      this.rows[table].push(row);
      return;
    }
    if (options?.ignoreDuplicates) return;
    this.rows[table][existingIndex] = {
      ...this.rows[table][existingIndex],
      ...row,
    };
  }
}

function buildService(admin: FakeSupabaseAdmin): WorkplaceSimulationService {
  return new WorkplaceSimulationService({
    admin,
  } as unknown as SupabaseService);
}

function baseRequest(): WmsSyncRequest {
  return {
    generatedScenario: {
      missionId: 'receive-incoming-shipment-01',
      resources: [],
    },
    attempt: {
      id: 'attempt-1',
      candidateId: 'candidate-1',
      missionId: 'receive-incoming-shipment-01',
      missionVersion: '1.0.0',
      attemptNumber: 1,
      scenarioSeed: 42,
      state: 'in_progress',
      timerStatus: 'running',
      currentStageId: 'receiving-dock',
      completedTaskIds: ['confirm-shipment-identity'],
      createdAt: '2026-07-31T10:00:00.000Z',
      briefingAcknowledgedAt: '2026-07-31T10:01:00.000Z',
      shiftStartedAt: '2026-07-31T10:02:00.000Z',
      elapsedSimulationSeconds: 120,
      actions: [
        {
          id: 'action-1',
          attemptId: 'attempt-1',
          missionId: 'receive-incoming-shipment-01',
          stageId: 'receiving-dock',
          taskId: 'confirm-shipment-identity',
          actionType: 'mark_match',
          targetId: 'delivery-note-1',
          payload: { conclusion: 'matchesExpectedDelivery' },
          sequenceNumber: 1,
          simulationTimeSeconds: 90,
          createdAt: '2026-07-31T10:03:30.000Z',
          isTechnical: false,
        },
      ],
      auditEvents: [
        {
          id: 'audit-1',
          attemptId: 'attempt-1',
          missionId: 'receive-incoming-shipment-01',
          missionVersion: '1.0.0',
          eventType: 'shiftStarted',
          screenId: 'supervisor-briefing',
          sequenceNumber: 1,
          simulationElapsedSeconds: 0,
          occurredAt: '2026-07-31T10:02:00.000Z',
          payload: {},
        },
      ],
    },
    result: {
      attemptId: 'attempt-1',
      missionId: 'receive-incoming-shipment-01',
      missionVersion: '1.0.0',
      scenarioSeed: 42,
      status: 'passed',
      overallScore: 82,
      categoryScores: { receiving: 82 },
      competencyScores: [{ competencyId: 'receiving-accuracy', score: 82 }],
      mandatoryTasksCompleted: true,
      criticalErrors: [],
      correctActions: ['action-1'],
      missedIssues: [],
      recommendedRemediationIds: [],
      completedAt: '2026-07-31T10:20:00.000Z',
      evidence: [
        {
          id: 'evidence-1',
          candidateId: 'candidate-1',
          attemptId: 'attempt-1',
          missionId: 'receive-incoming-shipment-01',
          missionVersion: '1.0.0',
          scenarioSeed: 42,
          competencyId: 'receiving-accuracy',
          score: 82,
          evidenceType: 'simulation_result',
          title: 'Receiving accuracy',
          description: 'Candidate completed the receiving simulation.',
          issuedAt: '2026-07-31T10:20:00.000Z',
          verificationStatus: 'systemObserved',
        },
      ],
    },
  };
}

describe('WorkplaceSimulationService', () => {
  it('syncs the attempt aggregate, learner actions, audit events, result and evidence', async () => {
    const admin = new FakeSupabaseAdmin();
    const service = buildService(admin);

    const summary = await service.syncAttempt(
      'candidate-1',
      'attempt-1',
      baseRequest(),
    );

    expect(summary).toEqual({
      attemptId: 'attempt-1',
      actionCount: 1,
      auditEventCount: 1,
      resultSynced: true,
      evidenceCount: 1,
    });
    expect(admin.rows.wms_attempts).toHaveLength(1);
    expect(admin.rows.wms_attempts[0]).toMatchObject({
      id: 'attempt-1',
      candidate_id: 'candidate-1',
      timer_status: 'running',
      elapsed_simulation_seconds: 120,
    });
    expect(admin.rows.wms_learner_actions[0]).toMatchObject({
      id: 'action-1',
      is_technical: false,
      sequence_number: 1,
    });
    expect(admin.rows.wms_attempt_audit_events[0]).toMatchObject({
      id: 'audit-1',
      event_type: 'shiftStarted',
      screen_id: 'supervisor-briefing',
    });
    expect(admin.rows.wms_attempt_results[0]).toMatchObject({
      attempt_id: 'attempt-1',
      status: 'passed',
    });
    expect(admin.rows.wms_competency_evidence[0]).toMatchObject({
      id: 'evidence-1',
      verification_status: 'systemObserved',
    });
  });

  it('is idempotent for repeated action and audit rows', async () => {
    const admin = new FakeSupabaseAdmin();
    const service = buildService(admin);
    const request = baseRequest();

    await service.syncAttempt('candidate-1', 'attempt-1', request);
    await service.syncAttempt('candidate-1', 'attempt-1', request);

    expect(admin.rows.wms_attempts).toHaveLength(1);
    expect(admin.rows.wms_learner_actions).toHaveLength(1);
    expect(admin.rows.wms_attempt_audit_events).toHaveLength(1);
    expect(admin.rows.wms_attempt_results).toHaveLength(1);
    expect(admin.rows.wms_competency_evidence).toHaveLength(1);
  });

  it('rejects technical events in the learner-action stream', async () => {
    const service = buildService(new FakeSupabaseAdmin());
    const request = baseRequest();
    request.attempt.actions![0].isTechnical = true;

    await expect(
      service.syncAttempt('candidate-1', 'attempt-1', request),
    ).rejects.toMatchObject({
      code: 'VALIDATION_ERROR',
    } satisfies Partial<AppError>);
  });

  it('rejects candidate id mismatches instead of trusting the body', async () => {
    const service = buildService(new FakeSupabaseAdmin());
    const request = baseRequest();
    request.attempt.candidateId = 'other-candidate';

    await expect(
      service.syncAttempt('candidate-1', 'attempt-1', request),
    ).rejects.toMatchObject({
      code: 'VALIDATION_ERROR',
    } satisfies Partial<AppError>);
  });
});
