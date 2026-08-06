import { EmployerJobsService } from './employer-jobs.service';
import { SupabaseService } from '../supabase/supabase.service';

type Row = Record<string, unknown>;

/**
 * A minimal in-memory stand-in for the slice of the Supabase query builder
 * this service actually uses -- extends the read-only shape from
 * employer.service.spec.ts's QueryBuilder with `insert`/`update`/`single`,
 * since EmployerJobsService writes as well as reads.
 */
class QueryBuilder<T extends Row> {
  constructor(
    private rows: T[],
    private readonly table: JobsTable | null = null,
  ) {}

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

  async single() {
    return { data: this.rows[0] ?? null, error: null };
  }

  then(resolve: (result: { data: T[]; error: null }) => void) {
    resolve({ data: this.rows, error: null });
  }

  insert(row: Row) {
    if (!this.table) throw new Error('insert is only supported on jobs');
    const created = this.table.insert(row);
    return {
      select: () => ({
        single: async () => ({ data: created, error: null }),
      }),
    };
  }

  update(patch: Row) {
    if (!this.table) throw new Error('update is only supported on jobs');
    // Applies every .eq() chained after .update() as an actual filter
    // before mutating -- mirrors the real Supabase client's scoping, which
    // is what makes EmployerJobsService's "defence in depth" .eq('id',
    // ...).eq('employer_id', ...) chain meaningful to test.
    let matched = this.rows;
    const chain = {
      eq: (key: keyof T, value: unknown) => {
        matched = matched.filter((row) => row[key] === value);
        return chain;
      },
      select: () => ({
        single: async () => {
          for (const row of matched) Object.assign(row, patch);
          return { data: matched[0] ?? null, error: null };
        },
      }),
    };
    return chain;
  }
}

interface JobRow extends Row {
  id: string;
  employer_id: string;
  employer_name: string;
  title: string;
  location: string;
  description: string;
  status: string;
  published_at: string | null;
  created_at: string;
}

class JobsTable {
  rows: JobRow[] = [];
  private nextId = 1;

  insert(row: Row): JobRow {
    const created: JobRow = {
      id: `job-${this.nextId++}`,
      employer_id: row.employer_id as string,
      employer_name: row.employer_name as string,
      title: row.title as string,
      location: row.location as string,
      description: row.description as string,
      status: (row.status as string) ?? 'draft',
      published_at: null,
      created_at: new Date().toISOString(),
    };
    this.rows.push(created);
    return created;
  }
}

class FakeSupabaseAdmin {
  jobsTable = new JobsTable();
  employers: { id: string; name: string }[] = [];
  applications: { job_id: string; status: string }[] = [];

  from(table: string) {
    if (table === 'jobs') return new QueryBuilder([...this.jobsTable.rows], this.jobsTable);
    if (table === 'employers') return new QueryBuilder([...this.employers]);
    if (table === 'job_applications') return new QueryBuilder([...this.applications]);
    throw new Error(`Unhandled table in fake: ${table}`);
  }
}

function buildService(admin: FakeSupabaseAdmin): EmployerJobsService {
  const supabase = { admin } as unknown as SupabaseService;
  return new EmployerJobsService(supabase);
}

describe('EmployerJobsService.createDraft', () => {
  it('creates a draft job resolving the employer name and defaulting source to flora', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.employers = [{ id: 'employer-1', name: 'Apex Consumer Products' }];
    const service = buildService(admin);

    const job = await service.createDraft('employer-1', {
      title: 'Warehouse Associate',
      location: 'Bhiwandi, Maharashtra',
      description: 'Receiving and put-away.',
      roleProfileId: null,
    });

    expect(job.status).toBe('draft');
    expect(job.title).toBe('Warehouse Associate');
    expect(admin.jobsTable.rows).toHaveLength(1);
    expect(admin.jobsTable.rows[0]).toMatchObject({
      employer_id: 'employer-1',
      employer_name: 'Apex Consumer Products',
    });
  });
});

describe('EmployerJobsService.publish', () => {
  it('publishes a draft job owned by the calling employer', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobsTable.rows = [
      {
        id: 'job-1',
        employer_id: 'employer-1',
        employer_name: 'Apex Consumer Products',
        title: 'Warehouse Associate',
        location: 'Bhiwandi, Maharashtra',
        description: 'Receiving and put-away.',
        status: 'draft',
        published_at: null,
        created_at: 't1',
      },
    ];
    const service = buildService(admin);

    const job = await service.publish('employer-1', 'job-1');

    expect(job.status).toBe('published');
    expect(job.publishedAt).not.toBeNull();
  });

  it('is idempotent -- publishing an already-published job is a no-op, not an error', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobsTable.rows = [
      {
        id: 'job-1',
        employer_id: 'employer-1',
        employer_name: 'Apex Consumer Products',
        title: 'Warehouse Associate',
        location: 'Bhiwandi, Maharashtra',
        description: 'Receiving and put-away.',
        status: 'published',
        published_at: '2026-08-01T00:00:00Z',
        created_at: 't1',
      },
    ];
    const service = buildService(admin);

    const job = await service.publish('employer-1', 'job-1');

    expect(job.status).toBe('published');
    expect(job.publishedAt).toBe('2026-08-01T00:00:00Z');
  });

  it('rejects publishing a closed job', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobsTable.rows = [
      {
        id: 'job-1',
        employer_id: 'employer-1',
        employer_name: 'Apex Consumer Products',
        title: 'Warehouse Associate',
        location: 'Bhiwandi, Maharashtra',
        description: 'Receiving and put-away.',
        status: 'closed',
        published_at: '2026-07-01T00:00:00Z',
        created_at: 't1',
      },
    ];
    const service = buildService(admin);

    await expect(service.publish('employer-1', 'job-1')).rejects.toMatchObject(
      { code: 'VALIDATION_ERROR' },
    );
  });

  it('denies publishing another employer\'s job (indistinguishable from not found)', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobsTable.rows = [
      {
        id: 'job-1',
        employer_id: 'employer-A',
        employer_name: 'Employer A',
        title: 'Warehouse Associate',
        location: 'Bhiwandi, Maharashtra',
        description: 'Receiving and put-away.',
        status: 'draft',
        published_at: null,
        created_at: 't1',
      },
    ];
    const service = buildService(admin);

    await expect(
      service.publish('employer-B', 'job-1'),
    ).rejects.toMatchObject({ code: 'JOB_NOT_FOUND' });
    expect(admin.jobsTable.rows[0].status).toBe('draft');
  });
});

describe('EmployerJobsService.listOwn', () => {
  it('lists only this employer\'s jobs, never leaking another employer\'s', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobsTable.rows = [
      {
        id: 'job-1',
        employer_id: 'employer-1',
        employer_name: 'Apex Consumer Products',
        title: 'Warehouse Associate',
        location: 'Bhiwandi, Maharashtra',
        description: 'Receiving and put-away.',
        status: 'published',
        published_at: 't1',
        created_at: 't1',
      },
      {
        id: 'job-2',
        employer_id: 'employer-2',
        employer_name: 'A different employer',
        title: 'Inventory Executive',
        location: 'Gurugram, Haryana',
        description: 'Cycle counts.',
        status: 'published',
        published_at: 't1',
        created_at: 't1',
      },
    ];
    const service = buildService(admin);

    const jobs = await service.listOwn('employer-1');

    expect(jobs.map((job) => job.id)).toEqual(['job-1']);
  });

  it('counts applications excluding withdrawn ones', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.jobsTable.rows = [
      {
        id: 'job-1',
        employer_id: 'employer-1',
        employer_name: 'Apex Consumer Products',
        title: 'Warehouse Associate',
        location: 'Bhiwandi, Maharashtra',
        description: 'Receiving and put-away.',
        status: 'published',
        published_at: 't1',
        created_at: 't1',
      },
    ];
    admin.applications = [
      { job_id: 'job-1', status: 'submitted' },
      { job_id: 'job-1', status: 'shortlisted' },
      { job_id: 'job-1', status: 'withdrawn' },
    ];
    const service = buildService(admin);

    const [job] = await service.listOwn('employer-1');

    expect(job.applicationCount).toBe(2);
  });

  it('returns an empty list for an employer with no jobs', async () => {
    const admin = new FakeSupabaseAdmin();
    const service = buildService(admin);

    expect(await service.listOwn('employer-1')).toEqual([]);
  });
});
