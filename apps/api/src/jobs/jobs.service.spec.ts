import { JobsService } from './jobs.service';
import { AppError } from '../common/app-error';
import { SupabaseService } from '../supabase/supabase.service';

/**
 * A minimal in-memory stand-in for the slice of the Supabase query builder
 * this service actually uses. It is deliberately not a general-purpose
 * fake -- it exists to prove JobsService's logic (consent gating,
 * idempotent apply, 404 on unpublished jobs) without a live database.
 */
class FakeSupabaseAdmin {
  jobs: { id: string; status: string }[] = [];
  consentGrants: { candidate_id: string; purpose: string; revoked_at: string | null }[] =
    [];
  applications: {
    id: string;
    job_id: string;
    candidate_id: string;
    status: string;
    created_at: string;
  }[] = [];
  private nextId = 1;

  from(table: string) {
    if (table === 'jobs') return this.jobsTable();
    if (table === 'consent_grants') return this.consentTable();
    if (table === 'job_applications') return this.applicationsTable();
    throw new Error(`Unhandled table in fake: ${table}`);
  }

  private jobsTable() {
    let filtered = this.jobs;
    const builder = {
      select: () => builder,
      eq: (key: 'id' | 'status', value: string) => {
        filtered = filtered.filter((row) => row[key] === value);
        return builder;
      },
      order: () => builder,
      maybeSingle: async () => ({ data: filtered[0] ?? null, error: null }),
      then: (resolve: (result: { data: unknown; error: null }) => void) =>
        resolve({ data: filtered, error: null }),
    };
    return builder;
  }

  private consentTable() {
    let filtered = this.consentGrants;
    const builder = {
      select: () => builder,
      eq: (key: 'candidate_id' | 'purpose', value: string) => {
        filtered = filtered.filter((row) => row[key] === value);
        return builder;
      },
      is: (key: 'revoked_at', value: null) => {
        filtered = filtered.filter((row) => row[key] === value);
        return builder;
      },
      limit: () => builder,
      maybeSingle: async () => ({ data: filtered[0] ?? null, error: null }),
    };
    return builder;
  }

  private applicationsTable() {
    let filtered = this.applications;
    const builder = {
      select: () => builder,
      eq: (key: 'job_id' | 'candidate_id', value: string) => {
        filtered = filtered.filter((row) => row[key] === value);
        return builder;
      },
      maybeSingle: async () => ({ data: filtered[0] ?? null, error: null }),
      then: (resolve: (result: { data: unknown; error: null }) => void) =>
        resolve({ data: filtered, error: null }),
      insert: (row: { job_id: string; candidate_id: string }) => {
        const created = {
          id: `app-${this.nextId++}`,
          job_id: row.job_id,
          candidate_id: row.candidate_id,
          status: 'submitted',
          created_at: new Date().toISOString(),
        };
        this.applications.push(created);
        return {
          select: () => ({
            single: async () => ({ data: created, error: null }),
          }),
        };
      },
    };
    return builder;
  }
}

function buildService(admin: FakeSupabaseAdmin): JobsService {
  const supabase = { admin } as unknown as SupabaseService;
  return new JobsService(supabase);
}

describe('JobsService', () => {
  it('lists only published jobs', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobs = [
      { id: 'job-1', status: 'published' },
      { id: 'job-2', status: 'draft' },
    ];
    const service = buildService(admin);

    const jobs = await service.listPublishedJobs();

    expect(jobs.map((job) => job.id)).toEqual(['job-1']);
  });

  it('passes through published_at so the mobile client can show/filter by posting date', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobs = [
      {
        id: 'job-1',
        status: 'published',
        published_at: '2026-08-05T14:47:59+00:00',
      } as unknown as { id: string; status: string },
    ];
    const service = buildService(admin);

    const jobs = await service.listPublishedJobs();

    expect(jobs[0].published_at).toBe('2026-08-05T14:47:59+00:00');
  });

  it('rejects applying to a job that is not published', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobs = [{ id: 'job-1', status: 'draft' }];
    const service = buildService(admin);

    await expect(
      service.applyToJob('candidate-1', 'job-1', 'key-1'),
    ).rejects.toMatchObject({ code: 'JOB_NOT_FOUND' });
  });

  it('rejects applying without active employer-sharing consent', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobs = [{ id: 'job-1', status: 'published' }];
    const service = buildService(admin);

    await expect(
      service.applyToJob('candidate-1', 'job-1', 'key-1'),
    ).rejects.toMatchObject({ code: 'CONSENT_REQUIRED' });
  });

  it('creates an application once consent is granted', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobs = [{ id: 'job-1', status: 'published' }];
    admin.consentGrants = [
      { candidate_id: 'candidate-1', purpose: 'employer_sharing', revoked_at: null },
    ];
    const service = buildService(admin);

    const result = await service.applyToJob('candidate-1', 'job-1', 'key-1');

    expect(result.created).toBe(true);
    expect(result.application.job_id).toBe('job-1');
    expect(result.application.candidate_id).toBe('candidate-1');
  });

  it('is idempotent: a repeat apply call returns the existing application', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobs = [{ id: 'job-1', status: 'published' }];
    admin.consentGrants = [
      { candidate_id: 'candidate-1', purpose: 'employer_sharing', revoked_at: null },
    ];
    const service = buildService(admin);

    const first = await service.applyToJob('candidate-1', 'job-1', 'key-1');
    const second = await service.applyToJob('candidate-1', 'job-1', 'key-2');

    expect(second.created).toBe(false);
    expect(second.application.id).toBe(first.application.id);
    expect(admin.applications).toHaveLength(1);
  });

  it('ignores a revoked employer-sharing consent', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobs = [{ id: 'job-1', status: 'published' }];
    admin.consentGrants = [
      {
        candidate_id: 'candidate-1',
        purpose: 'employer_sharing',
        revoked_at: new Date().toISOString(),
      },
    ];
    const service = buildService(admin);

    await expect(
      service.applyToJob('candidate-1', 'job-1', 'key-1'),
    ).rejects.toMatchObject({ code: 'CONSENT_REQUIRED' });
  });

  it('lists only the applications belonging to the requesting candidate', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.applications = [
      {
        id: 'app-1',
        job_id: 'job-1',
        candidate_id: 'candidate-1',
        status: 'submitted',
        created_at: new Date().toISOString(),
      },
      {
        id: 'app-2',
        job_id: 'job-2',
        candidate_id: 'candidate-2',
        status: 'submitted',
        created_at: new Date().toISOString(),
      },
    ];
    const service = buildService(admin);

    const jobIds = await service.listApplicationsForCandidate('candidate-1');

    expect(jobIds).toEqual(['job-1']);
  });
});

describe('AppError', () => {
  it('carries a stable machine code', () => {
    const error = AppError.notFound('JOB_NOT_FOUND', 'nope');
    expect(error.code).toBe('JOB_NOT_FOUND');
  });
});
