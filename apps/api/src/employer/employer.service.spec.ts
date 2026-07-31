import { EmployerService } from './employer.service';
import { SupabaseService } from '../supabase/supabase.service';

type Row = Record<string, unknown>;

/**
 * A minimal in-memory stand-in for the slice of the Supabase query builder
 * this service actually uses -- same approach as jobs.service.spec.ts.
 */
class QueryBuilder<T extends Row> {
  constructor(private rows: T[]) {}

  select() {
    return this;
  }

  eq(key: keyof T, value: unknown) {
    this.rows = this.rows.filter((row) => row[key] === value);
    return this;
  }

  neq(key: keyof T, value: unknown) {
    this.rows = this.rows.filter((row) => row[key] !== value);
    return this;
  }

  in(key: keyof T, values: unknown[]) {
    this.rows = this.rows.filter((row) => values.includes(row[key]));
    return this;
  }

  is(key: keyof T, value: null) {
    this.rows = this.rows.filter((row) => row[key] === value);
    return this;
  }

  order(key: keyof T, opts?: { ascending?: boolean }) {
    const ascending = opts?.ascending ?? true;
    this.rows = [...this.rows].sort((a, b) => {
      const left = String(a[key]);
      const right = String(b[key]);
      if (left === right) return 0;
      return (left < right ? -1 : 1) * (ascending ? 1 : -1);
    });
    return this;
  }

  limit() {
    return this;
  }

  async maybeSingle() {
    return { data: this.rows[0] ?? null, error: null };
  }

  then(resolve: (result: { data: T[]; error: null }) => void) {
    resolve({ data: this.rows, error: null });
  }
}

class FakeSupabaseAdmin {
  jobs: { id: string; employer_id: string; title: string }[] = [];
  applications: {
    candidate_id: string;
    job_id: string;
    status: string;
    created_at: string;
  }[] = [];
  consentGrants: {
    candidate_id: string;
    purpose: string;
    revoked_at: string | null;
  }[] = [];
  evidenceRows: { candidate_id: string; issued_at: string; evidence: unknown }[] = [];
  accessLogs: {
    employer_id: string;
    candidate_id: string;
    job_id: string | null;
    outcome: string;
    denial_reason: string | null;
  }[] = [];

  from(table: string) {
    if (table === 'jobs') return new QueryBuilder([...this.jobs]);
    if (table === 'job_applications') return new QueryBuilder([...this.applications]);
    if (table === 'consent_grants') return new QueryBuilder([...this.consentGrants]);
    if (table === 'wms_competency_evidence') return new QueryBuilder([...this.evidenceRows]);
    if (table === 'employer_evidence_access_log') {
      return {
        insert: async (row: (typeof this.accessLogs)[number]) => {
          this.accessLogs.push(row);
          return { error: null };
        },
      };
    }
    throw new Error(`Unhandled table in fake: ${table}`);
  }
}

function buildService(admin: FakeSupabaseAdmin): EmployerService {
  const supabase = { admin } as unknown as SupabaseService;
  return new EmployerService(supabase);
}

function grantConsent(admin: FakeSupabaseAdmin, candidateId: string) {
  admin.consentGrants.push(
    { candidate_id: candidateId, purpose: 'employer_sharing', revoked_at: null },
    { candidate_id: candidateId, purpose: 'career_passport_sharing', revoked_at: null },
  );
}

describe('EmployerService.listApplicants', () => {
  it('lists only applicants to this employer\'s own jobs, excluding withdrawn', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobs = [
      { id: 'job-1', employer_id: 'employer-1', title: 'Warehouse Associate' },
      { id: 'job-2', employer_id: 'employer-2', title: 'A different employer\'s job' },
    ];
    admin.applications = [
      { candidate_id: 'candidate-1', job_id: 'job-1', status: 'submitted', created_at: 't1' },
      { candidate_id: 'candidate-2', job_id: 'job-1', status: 'withdrawn', created_at: 't2' },
      { candidate_id: 'candidate-3', job_id: 'job-2', status: 'submitted', created_at: 't3' },
    ];
    const service = buildService(admin);

    const applicants = await service.listApplicants('employer-1');

    expect(applicants).toEqual([
      {
        candidateId: 'candidate-1',
        jobId: 'job-1',
        jobTitle: 'Warehouse Associate',
        applicationStatus: 'submitted',
        appliedAt: 't1',
      },
    ]);
  });

  it('returns nothing for an employer with no jobs', async () => {
    const admin = new FakeSupabaseAdmin();
    const service = buildService(admin);

    expect(await service.listApplicants('employer-1')).toEqual([]);
  });
});

describe('EmployerService.reviewCandidateEvidence', () => {
  it('denies and audits when the candidate never applied to this employer', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobs = [{ id: 'job-1', employer_id: 'employer-1', title: 'Warehouse Associate' }];
    const service = buildService(admin);

    await expect(
      service.reviewCandidateEvidence('employer-1', 'candidate-1'),
    ).rejects.toMatchObject({ code: 'EMPLOYER_ACCESS_DENIED' });
    expect(admin.accessLogs).toEqual([
      {
        employer_id: 'employer-1',
        candidate_id: 'candidate-1',
        job_id: null,
        outcome: 'denied',
        denial_reason: 'NO_ACTIVE_APPLICATION',
      },
    ]);
  });

  it('denies a withdrawn application even if it once existed', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobs = [{ id: 'job-1', employer_id: 'employer-1', title: 'Warehouse Associate' }];
    admin.applications = [
      { candidate_id: 'candidate-1', job_id: 'job-1', status: 'withdrawn', created_at: 't1' },
    ];
    grantConsent(admin, 'candidate-1');
    const service = buildService(admin);

    await expect(
      service.reviewCandidateEvidence('employer-1', 'candidate-1'),
    ).rejects.toMatchObject({ code: 'EMPLOYER_ACCESS_DENIED' });
  });

  it('denies and audits when sharing consent is not active', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobs = [{ id: 'job-1', employer_id: 'employer-1', title: 'Warehouse Associate' }];
    admin.applications = [
      { candidate_id: 'candidate-1', job_id: 'job-1', status: 'submitted', created_at: 't1' },
    ];
    const service = buildService(admin);

    await expect(
      service.reviewCandidateEvidence('employer-1', 'candidate-1'),
    ).rejects.toMatchObject({ code: 'EMPLOYER_ACCESS_DENIED' });
    expect(admin.accessLogs).toEqual([
      {
        employer_id: 'employer-1',
        candidate_id: 'candidate-1',
        job_id: 'job-1',
        outcome: 'denied',
        denial_reason: 'SHARING_NOT_ACTIVE',
      },
    ]);
  });

  it('returns disclaimer, decision boundary and freshness-labelled evidence when access is allowed', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobs = [{ id: 'job-1', employer_id: 'employer-1', title: 'Warehouse Associate' }];
    admin.applications = [
      { candidate_id: 'candidate-1', job_id: 'job-1', status: 'submitted', created_at: 't1' },
    ];
    grantConsent(admin, 'candidate-1');
    admin.evidenceRows = [
      {
        candidate_id: 'candidate-1',
        issued_at: '2026-07-25T00:00:00Z',
        evidence: {
          id: 'evidence-1',
          attemptId: 'attempt-1',
          missionId: 'mission-1',
          missionVersion: '1.0.0',
          scenarioSeed: 1,
          competencyId: 'receiving-accuracy',
          score: 82,
          evidenceType: 'simulation_observation',
          title: 'Observed Receiving Accuracy',
          description: 'Generated from the append-only action trail.',
          issuedAt: '2026-07-25T00:00:00Z',
          verificationStatus: 'systemObserved',
        },
      },
    ];
    const service = buildService(admin);

    const view = await service.reviewCandidateEvidence('employer-1', 'candidate-1');

    expect(view.disclaimer).toBe('Flora provides simulation evidence, not certification.');
    expect(view.decisionBoundary).toBe('Employer reviews evidence and decides.');
    expect(view.evidence).toHaveLength(1);
    expect(view.evidence[0]).toMatchObject({ id: 'evidence-1', freshness: 'active' });
    expect(admin.accessLogs).toEqual([
      {
        employer_id: 'employer-1',
        candidate_id: 'candidate-1',
        job_id: 'job-1',
        outcome: 'allowed',
        denial_reason: null,
      },
    ]);
  });
});
