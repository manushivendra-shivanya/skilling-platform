import { ShiftsService } from './shifts.service';
import { SupabaseService } from '../supabase/supabase.service';

type Row = Record<string, unknown>;

/**
 * A minimal in-memory stand-in for the slice of the Supabase query builder
 * this service actually uses -- follows the exact shape established by
 * jobs.service.spec.ts / employer-jobs.service.spec.ts (this codebase has
 * no shared fake; each spec file writes its own, deliberately not a
 * general-purpose mock).
 */
class QueryBuilder<T extends Row> {
  private countMode = false;

  constructor(
    private rows: T[],
    private readonly table: MutableTable<T> | null = null,
  ) {}

  select(_columns?: string, opts?: { count?: 'exact'; head?: boolean }) {
    this.countMode = opts?.head === true;
    return this;
  }

  eq(key: keyof T, value: unknown) {
    this.rows = this.rows.filter((row) => row[key] === value);
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

  then(resolve: (result: { data: T[]; error: null; count: number }) => void) {
    resolve({ data: this.rows, error: null, count: this.rows.length });
  }

  insert(row: Row) {
    if (!this.table) throw new Error('insert is not supported on this table');
    const created = this.table.insert(row);
    return {
      select: () => ({
        single: async () => ({ data: created, error: null }),
      }),
    };
  }

  update(patch: Row) {
    if (!this.table) throw new Error('update is not supported on this table');
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

  upsert(row: Row) {
    if (!this.table) throw new Error('upsert is not supported on this table');
    this.table.upsert(row);
    return { then: (resolve: (r: { error: null }) => void) => resolve({ error: null }) };
  }
}

interface MutableTable<T extends Row> {
  insert(row: Row): T;
  upsert(row: Row): T;
}

interface ShiftRequestRow extends Row {
  id: string;
  headcount: number;
  pay_amount: string;
  check_in_code: string;
  status: string;
}

interface ShiftApplicationRow extends Row {
  id: string;
  shift_id: string;
  candidate_id: string;
  status: string;
  checked_in_at: string | null;
  checked_out_at: string | null;
  created_at: string;
}

class ShiftApplicationsTable implements MutableTable<ShiftApplicationRow> {
  rows: ShiftApplicationRow[] = [];
  private nextId = 1;

  insert(row: Row): ShiftApplicationRow {
    const created: ShiftApplicationRow = {
      id: `app-${this.nextId++}`,
      shift_id: row.shift_id as string,
      candidate_id: row.candidate_id as string,
      status: 'accepted',
      checked_in_at: null,
      checked_out_at: null,
      created_at: new Date().toISOString(),
    };
    this.rows.push(created);
    return created;
  }

  upsert(): ShiftApplicationRow {
    throw new Error('shift_applications is never upserted');
  }
}

interface ShiftPayoutRow extends Row {
  shift_application_id: string;
  candidate_id: string;
  base_pay: string;
  total: string;
  status: string;
}

class ShiftPayoutsTable implements MutableTable<ShiftPayoutRow> {
  rows: ShiftPayoutRow[] = [];

  insert(): ShiftPayoutRow {
    throw new Error('shift_payouts is only ever upserted by this service');
  }

  upsert(row: Row): ShiftPayoutRow {
    const created: ShiftPayoutRow = {
      shift_application_id: row.shift_application_id as string,
      candidate_id: row.candidate_id as string,
      base_pay: row.base_pay as string,
      total: row.total as string,
      status: 'pending_approval',
    };
    this.rows = this.rows.filter(
      (existing) =>
        existing.shift_application_id !== created.shift_application_id,
    );
    this.rows.push(created);
    return created;
  }
}

class FakeSupabaseAdmin {
  shiftRequests: ShiftRequestRow[] = [];
  applicationsTable = new ShiftApplicationsTable();
  payoutsTable = new ShiftPayoutsTable();

  from(table: string) {
    if (table === 'shift_requests') {
      return new QueryBuilder([...this.shiftRequests]);
    }
    if (table === 'shift_applications') {
      return new QueryBuilder(
        [...this.applicationsTable.rows],
        this.applicationsTable,
      );
    }
    if (table === 'shift_payouts') {
      return new QueryBuilder([...this.payoutsTable.rows], this.payoutsTable);
    }
    throw new Error(`Unhandled table in fake: ${table}`);
  }
}

function buildService(admin: FakeSupabaseAdmin): ShiftsService {
  const supabase = { admin } as unknown as SupabaseService;
  return new ShiftsService(supabase);
}

function shift(overrides: Partial<ShiftRequestRow> = {}): ShiftRequestRow {
  return {
    id: 'shift-1',
    role_title: 'Picker / Packer',
    site_name: 'Dark store',
    site_address: '1 Main Rd',
    city: 'Bengaluru',
    starts_at: '2026-08-10T12:00:00Z',
    ends_at: '2026-08-10T18:00:00Z',
    reporting_time: null,
    headcount: 2,
    pay_amount: '650.00',
    pay_currency: 'INR',
    required_competency_ids: [],
    description: null,
    supervisor_name: null,
    supervisor_contact: null,
    cancellation_policy: null,
    check_in_code: '123456',
    status: 'published',
    ...overrides,
  };
}

describe('ShiftsService.listPublished / getById', () => {
  it('lists only published shifts', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.shiftRequests = [shift(), shift({ id: 'shift-2', status: 'draft' })];
    const service = buildService(admin);

    const shifts = await service.listPublished();

    expect(shifts.map((s) => s.id)).toEqual(['shift-1']);
  });

  it('404s a shift that is not published', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.shiftRequests = [shift({ status: 'draft' })];
    const service = buildService(admin);

    await expect(service.getById('shift-1')).rejects.toMatchObject({
      code: 'SHIFT_NOT_FOUND',
    });
  });
});

describe('ShiftsService.applyToShift', () => {
  it('accepts a shift with room left', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.shiftRequests = [shift()];
    const service = buildService(admin);

    const result = await service.applyToShift('candidate-1', 'shift-1', 'key-1');

    expect(result.created).toBe(true);
    expect(result.application.status).toBe('accepted');
  });

  it('is idempotent: a repeat accept call returns the existing application', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.shiftRequests = [shift()];
    const service = buildService(admin);

    const first = await service.applyToShift('candidate-1', 'shift-1', 'key-1');
    const second = await service.applyToShift('candidate-1', 'shift-1', 'key-2');

    expect(second.created).toBe(false);
    expect(second.application.id).toBe(first.application.id);
    expect(admin.applicationsTable.rows).toHaveLength(1);
  });

  it('rejects once the shift is fully staffed', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.shiftRequests = [shift({ headcount: 1 })];
    admin.applicationsTable.rows = [
      {
        id: 'app-existing',
        shift_id: 'shift-1',
        candidate_id: 'candidate-other',
        status: 'accepted',
        checked_in_at: null,
        checked_out_at: null,
        created_at: 't0',
      },
    ];
    const service = buildService(admin);

    await expect(
      service.applyToShift('candidate-1', 'shift-1', 'key-1'),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
  });
});

describe('ShiftsService.checkIn / checkOut', () => {
  function withAcceptedApplication(admin: FakeSupabaseAdmin) {
    admin.shiftRequests = [shift()];
    admin.applicationsTable.rows = [
      {
        id: 'app-1',
        shift_id: 'shift-1',
        candidate_id: 'candidate-1',
        status: 'accepted',
        checked_in_at: null,
        checked_out_at: null,
        created_at: 't0',
      },
    ];
  }

  it('checks in with the correct code', async () => {
    const admin = new FakeSupabaseAdmin();
    withAcceptedApplication(admin);
    const service = buildService(admin);

    const application = await service.checkIn('candidate-1', 'app-1', '123456');

    expect(application.status).toBe('checked_in');
    expect(application.checked_in_at).not.toBeNull();
  });

  it('rejects a mismatched check-in code', async () => {
    const admin = new FakeSupabaseAdmin();
    withAcceptedApplication(admin);
    const service = buildService(admin);

    await expect(
      service.checkIn('candidate-1', 'app-1', 'wrong'),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
  });

  it('denies checking in another candidate\'s application', async () => {
    const admin = new FakeSupabaseAdmin();
    withAcceptedApplication(admin);
    const service = buildService(admin);

    await expect(
      service.checkIn('candidate-2', 'app-1', '123456'),
    ).rejects.toMatchObject({ code: 'SHIFT_APPLICATION_NOT_FOUND' });
  });

  it('checks out and creates a pending_approval payout row -- never moves money', async () => {
    const admin = new FakeSupabaseAdmin();
    withAcceptedApplication(admin);
    admin.applicationsTable.rows[0].status = 'checked_in';
    const service = buildService(admin);

    const application = await service.checkOut('candidate-1', 'app-1');

    expect(application.status).toBe('completed');
    expect(application.checked_out_at).not.toBeNull();
    expect(admin.payoutsTable.rows).toHaveLength(1);
    expect(admin.payoutsTable.rows[0]).toMatchObject({
      shift_application_id: 'app-1',
      candidate_id: 'candidate-1',
      base_pay: '650.00',
      total: '650.00',
      status: 'pending_approval',
    });
  });

  it('rejects checking out before checking in', async () => {
    const admin = new FakeSupabaseAdmin();
    withAcceptedApplication(admin);
    const service = buildService(admin);

    await expect(
      service.checkOut('candidate-1', 'app-1'),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
  });
});
