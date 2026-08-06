import { JobSyncService } from './job-sync.service';
import { JobSourceAdapter, ExternalJobListing } from './job-source-adapter';
import { SupabaseService } from '../../supabase/supabase.service';

/**
 * A minimal in-memory stand-in for the slice of the Supabase query builder
 * JobSyncService actually uses: `jobs.upsert(rows, { onConflict })` and
 * `job_sync_runs.insert(row)`. Upsert is keyed on (source, external_id),
 * mirroring the real unique index, so re-syncing identical fixture data
 * doesn't duplicate rows.
 */
class FakeSupabaseAdmin {
  jobs: Record<string, unknown>[] = [];
  jobSyncRuns: Record<string, unknown>[] = [];

  from(table: string) {
    if (table === 'jobs') return this.jobsTable();
    if (table === 'job_sync_runs') return this.jobSyncRunsTable();
    throw new Error(`Unhandled table in fake: ${table}`);
  }

  private jobsTable() {
    return {
      upsert: async (rows: Record<string, unknown>[]) => {
        for (const row of rows) {
          const index = this.jobs.findIndex(
            (existing) =>
              existing.source === row.source &&
              existing.external_id === row.external_id,
          );
          if (index >= 0) {
            this.jobs[index] = row;
          } else {
            this.jobs.push(row);
          }
        }
        return { error: null };
      },
    };
  }

  private jobSyncRunsTable() {
    return {
      insert: async (row: Record<string, unknown>) => {
        this.jobSyncRuns.push(row);
        return { error: null };
      },
    };
  }
}

function fakeAdapter(
  key: string,
  listings: ExternalJobListing[],
): JobSourceAdapter {
  return { key, fetchJobs: async () => listings };
}

function throwingAdapter(key: string, message: string): JobSourceAdapter {
  return {
    key,
    fetchJobs: async () => {
      throw new Error(message);
    },
  };
}

function listing(externalId: string): ExternalJobListing {
  return {
    externalId,
    employerName: 'Acme Corp',
    title: 'Warehouse Associate',
    location: 'Bhiwandi, Maharashtra',
    description: 'Receiving and put-away.',
    applyUrl: `https://example.com/jobs/${externalId}`,
  };
}

function buildService(
  admin: FakeSupabaseAdmin,
  adapters: JobSourceAdapter[],
): JobSyncService {
  const supabase = { admin } as unknown as SupabaseService;
  return new JobSyncService(adapters, supabase);
}

describe('JobSyncService', () => {
  it('upserts every adapter\'s listings and records one job_sync_runs row per adapter', async () => {
    const admin = new FakeSupabaseAdmin();
    const service = buildService(admin, [
      fakeAdapter('adzuna', [listing('a-1'), listing('a-2')]),
      fakeAdapter('jooble', [listing('j-1')]),
    ]);

    const results = await service.syncAll('cron');

    expect(results).toEqual([
      { source: 'adzuna', ok: true, jobsSeen: 2, jobsUpserted: 2 },
      { source: 'jooble', ok: true, jobsSeen: 1, jobsUpserted: 1 },
    ]);
    expect(admin.jobs).toHaveLength(3);
    expect(admin.jobSyncRuns).toHaveLength(2);
    expect(admin.jobSyncRuns.every((run) => run.triggered_by === 'cron')).toBe(
      true,
    );
  });

  it('isolates a throwing adapter -- other adapters still sync and get an audit row', async () => {
    const admin = new FakeSupabaseAdmin();
    const service = buildService(admin, [
      throwingAdapter('careerjet', 'boom'),
      fakeAdapter('adzuna', [listing('a-1')]),
    ]);

    const results = await service.syncAll('cron');

    expect(results).toEqual([
      {
        source: 'careerjet',
        ok: false,
        jobsSeen: 0,
        jobsUpserted: 0,
        error: 'boom',
      },
      { source: 'adzuna', ok: true, jobsSeen: 1, jobsUpserted: 1 },
    ]);
    expect(admin.jobs).toHaveLength(1);
    expect(admin.jobSyncRuns).toHaveLength(2);
    const failedRun = admin.jobSyncRuns.find(
      (run) => run.source === 'careerjet',
    );
    expect(failedRun?.error).toBe('boom');
  });

  it('re-syncing identical fixture data does not duplicate jobs rows (idempotent upsert)', async () => {
    const admin = new FakeSupabaseAdmin();
    const service = buildService(admin, [
      fakeAdapter('adzuna', [listing('a-1')]),
    ]);

    await service.syncAll('cron');
    await service.syncAll('cron');

    expect(admin.jobs).toHaveLength(1);
    expect(admin.jobSyncRuns).toHaveLength(2);
  });

  it('syncSource runs only the named adapter', async () => {
    const admin = new FakeSupabaseAdmin();
    const service = buildService(admin, [
      fakeAdapter('adzuna', [listing('a-1')]),
      fakeAdapter('jooble', [listing('j-1')]),
    ]);

    const result = await service.syncSource('jooble', 'manual');

    expect(result).toEqual({
      source: 'jooble',
      ok: true,
      jobsSeen: 1,
      jobsUpserted: 1,
    });
    expect(admin.jobs).toEqual([expect.objectContaining({ source: 'jooble' })]);
    expect(admin.jobSyncRuns).toHaveLength(1);
    expect(admin.jobSyncRuns[0].triggered_by).toBe('manual');
  });

  it('syncSource rejects an unknown source', async () => {
    const admin = new FakeSupabaseAdmin();
    const service = buildService(admin, [fakeAdapter('adzuna', [])]);

    await expect(service.syncSource('not-a-real-source')).rejects.toMatchObject(
      { code: 'JOB_SOURCE_NOT_FOUND' },
    );
  });
});
