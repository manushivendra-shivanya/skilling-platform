import { CareerPassportService } from './career-passport.service';
import { SupabaseService } from '../supabase/supabase.service';

type Row = Record<string, unknown>;

/**
 * Same minimal in-memory query-builder stand-in used by
 * employer.service.spec.ts -- only the operations this service actually
 * calls.
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

  not(key: keyof T, operator: 'is', value: null) {
    if (operator !== 'is' || value !== null) {
      throw new Error('Fake QueryBuilder.not only supports not(key, "is", null)');
    }
    this.rows = this.rows.filter((row) => row[key] !== null);
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

  async maybeSingle() {
    return { data: this.rows[0] ?? null, error: null };
  }

  then(resolve: (result: { data: T[]; error: null }) => void) {
    resolve({ data: this.rows, error: null });
  }
}

class FakeSupabaseAdmin {
  grants: {
    id: string;
    candidate_id: string;
    purpose: string;
    token: string;
    revoked_at: string | null;
    expires_at: string | null;
  }[] = [];
  evidenceRows: { candidate_id: string; issued_at: string; evidence: unknown }[] = [];
  applications: { candidate_id: string; job_id: string; status: string }[] = [];
  jobs: { id: string; employer_id: string | null }[] = [];
  employers: { id: string; name: string }[] = [];
  accessLogs: {
    grant_id: string | null;
    outcome: string;
    denial_reason: string | null;
  }[] = [];

  from(table: string) {
    if (table === 'career_passport_grants') return new QueryBuilder([...this.grants]);
    if (table === 'wms_competency_evidence') return new QueryBuilder([...this.evidenceRows]);
    if (table === 'job_applications') return new QueryBuilder([...this.applications]);
    if (table === 'jobs') return new QueryBuilder([...this.jobs]);
    if (table === 'employers') return new QueryBuilder([...this.employers]);
    if (table === 'career_passport_grant_access_log') {
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

function buildService(admin: FakeSupabaseAdmin): CareerPassportService {
  const supabase = { admin } as unknown as SupabaseService;
  return new CareerPassportService(supabase);
}

describe('CareerPassportService.resolveShareLink', () => {
  it('denies and audits an unknown token', async () => {
    const admin = new FakeSupabaseAdmin();
    const service = buildService(admin);

    expect(await service.resolveShareLink('missing-token')).toEqual({
      status: 'not_found',
    });
    expect(admin.accessLogs).toEqual([
      { grant_id: null, outcome: 'denied', denial_reason: 'NOT_FOUND' },
    ]);
  });

  it('denies and audits a revoked link', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.grants = [
      {
        id: 'grant-1',
        candidate_id: 'candidate-1',
        purpose: 'public_link',
        token: 'token-1',
        revoked_at: '2026-07-30T00:00:00Z',
        expires_at: null,
      },
    ];
    const service = buildService(admin);

    expect(await service.resolveShareLink('token-1')).toEqual({ status: 'revoked' });
    expect(admin.accessLogs).toEqual([
      { grant_id: 'grant-1', outcome: 'denied', denial_reason: 'REVOKED' },
    ]);
  });

  it('denies and audits an expired link', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.grants = [
      {
        id: 'grant-1',
        candidate_id: 'candidate-1',
        purpose: 'public_link',
        token: 'token-1',
        revoked_at: null,
        expires_at: '2020-01-01T00:00:00Z',
      },
    ];
    const service = buildService(admin);

    expect(await service.resolveShareLink('token-1')).toEqual({ status: 'expired' });
    expect(admin.accessLogs).toEqual([
      { grant_id: 'grant-1', outcome: 'denied', denial_reason: 'EXPIRED' },
    ]);
  });

  it('allows and audits a valid link, returning freshness-labelled evidence', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.grants = [
      {
        id: 'grant-1',
        candidate_id: 'candidate-1',
        purpose: 'public_link',
        token: 'token-1',
        revoked_at: null,
        expires_at: '2099-01-01T00:00:00Z',
      },
    ];
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
          score: 90,
          evidenceType: 'simulation_observation',
          title: 'Receiving accuracy demonstrated',
          description: 'Generated from the append-only action trail.',
          issuedAt: '2026-07-25T00:00:00Z',
          verificationStatus: 'systemObserved',
        },
      },
    ];
    const service = buildService(admin);

    const result = await service.resolveShareLink('token-1');

    expect(result.status).toBe('ok');
    if (result.status !== 'ok') throw new Error('expected ok');
    expect(result.evidence).toHaveLength(1);
    expect(result.evidence[0]).toMatchObject({
      competencyId: 'receiving-accuracy',
      freshness: 'active',
    });
    expect(admin.accessLogs).toEqual([
      { grant_id: 'grant-1', outcome: 'allowed', denial_reason: null },
    ]);
  });

  it('does not resolve an employer-review grant as a public link', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.grants = [
      {
        id: 'grant-1',
        candidate_id: 'candidate-1',
        purpose: 'employer_review',
        token: 'token-1',
        revoked_at: null,
        expires_at: null,
      },
    ];
    const service = buildService(admin);

    expect(await service.resolveShareLink('token-1')).toEqual({ status: 'not_found' });
  });
});

describe('CareerPassportService.listAppliedEmployers', () => {
  it('returns nothing for a candidate with no applications', async () => {
    const admin = new FakeSupabaseAdmin();
    const service = buildService(admin);

    expect(await service.listAppliedEmployers('candidate-1')).toEqual([]);
  });

  it('excludes a withdrawn application', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.applications = [
      { candidate_id: 'candidate-1', job_id: 'job-1', status: 'withdrawn' },
    ];
    admin.jobs = [{ id: 'job-1', employer_id: 'employer-1' }];
    admin.employers = [{ id: 'employer-1', name: 'Apex Consumer Products' }];
    const service = buildService(admin);

    expect(await service.listAppliedEmployers('candidate-1')).toEqual([]);
  });

  it('deduplicates employers across multiple applications and sorts by name', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.applications = [
      { candidate_id: 'candidate-1', job_id: 'job-1', status: 'submitted' },
      { candidate_id: 'candidate-1', job_id: 'job-2', status: 'submitted' },
      { candidate_id: 'candidate-1', job_id: 'job-3', status: 'submitted' },
    ];
    admin.jobs = [
      { id: 'job-1', employer_id: 'employer-2' },
      { id: 'job-2', employer_id: 'employer-1' },
      // Same employer as job-1, different job -- must not appear twice.
      { id: 'job-3', employer_id: 'employer-2' },
    ];
    admin.employers = [
      { id: 'employer-1', name: 'Apex Consumer Products' },
      { id: 'employer-2', name: 'Meridian Logistics' },
    ];
    const service = buildService(admin);

    expect(await service.listAppliedEmployers('candidate-1')).toEqual([
      { id: 'employer-1', name: 'Apex Consumer Products' },
      { id: 'employer-2', name: 'Meridian Logistics' },
    ]);
  });

  it('ignores jobs with no employer_id', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.applications = [
      { candidate_id: 'candidate-1', job_id: 'job-1', status: 'submitted' },
    ];
    admin.jobs = [{ id: 'job-1', employer_id: null }];
    const service = buildService(admin);

    expect(await service.listAppliedEmployers('candidate-1')).toEqual([]);
  });
});
