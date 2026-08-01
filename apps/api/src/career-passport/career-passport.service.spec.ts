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
  accessLogs: {
    grant_id: string | null;
    outcome: string;
    denial_reason: string | null;
  }[] = [];

  from(table: string) {
    if (table === 'career_passport_grants') return new QueryBuilder([...this.grants]);
    if (table === 'wms_competency_evidence') return new QueryBuilder([...this.evidenceRows]);
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
