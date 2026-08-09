import { EmployerShiftsService } from './employer-shifts.service';
import { SupabaseService } from '../supabase/supabase.service';

type Row = Record<string, unknown>;

/**
 * Same shape as employer-jobs.service.spec.ts's QueryBuilder -- this
 * codebase has no shared fake, each spec file writes its own.
 */
class QueryBuilder<T extends Row> {
  constructor(
    private rows: T[],
    private readonly table: ShiftsTable | null = null,
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
    if (!this.table) throw new Error('insert is only supported on shift_requests');
    const created = this.table.insert(row);
    return {
      select: () => ({
        single: async () => ({ data: created, error: null }),
      }),
    };
  }

  update(patch: Row) {
    if (!this.table) throw new Error('update is only supported on shift_requests');
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

interface ShiftRow extends Row {
  id: string;
  employer_id: string;
  role_title: string;
  site_name: string;
  site_address: string;
  city: string;
  starts_at: string;
  ends_at: string;
  reporting_time: string | null;
  headcount: number;
  pay_amount: number;
  pay_currency: string;
  required_competency_ids: string[];
  description: string | null;
  supervisor_name: string | null;
  supervisor_contact: string | null;
  cancellation_policy: string | null;
  check_in_code: string;
  status: string;
}

class ShiftsTable {
  rows: ShiftRow[] = [];
  private nextId = 1;

  insert(row: Row): ShiftRow {
    const created: ShiftRow = {
      id: `shift-${this.nextId++}`,
      employer_id: row.employer_id as string,
      role_title: row.role_title as string,
      site_name: row.site_name as string,
      site_address: row.site_address as string,
      city: row.city as string,
      starts_at: row.starts_at as string,
      ends_at: row.ends_at as string,
      reporting_time: (row.reporting_time as string | null) ?? null,
      headcount: row.headcount as number,
      pay_amount: row.pay_amount as number,
      pay_currency: 'INR',
      required_competency_ids: (row.required_competency_ids as string[]) ?? [],
      description: (row.description as string | null) ?? null,
      supervisor_name: (row.supervisor_name as string | null) ?? null,
      supervisor_contact: (row.supervisor_contact as string | null) ?? null,
      cancellation_policy: (row.cancellation_policy as string | null) ?? null,
      check_in_code: row.check_in_code as string,
      status: (row.status as string) ?? 'draft',
    };
    this.rows.push(created);
    return created;
  }
}

class FakeSupabaseAdmin {
  shiftsTable = new ShiftsTable();
  applications: { shift_id: string; status: string }[] = [];

  from(table: string) {
    if (table === 'shift_requests') {
      return new QueryBuilder([...this.shiftsTable.rows], this.shiftsTable);
    }
    if (table === 'shift_applications') {
      return new QueryBuilder([...this.applications]);
    }
    throw new Error(`Unhandled table in fake: ${table}`);
  }
}

function buildService(admin: FakeSupabaseAdmin): EmployerShiftsService {
  const supabase = { admin } as unknown as SupabaseService;
  return new EmployerShiftsService(supabase);
}

const draftInput = {
  roleTitle: 'Picker / Packer',
  siteName: 'Dark store',
  siteAddress: '1 Main Rd',
  city: 'Bengaluru',
  startsAt: '2026-08-10T12:00:00Z',
  endsAt: '2026-08-10T18:00:00Z',
  reportingTime: null,
  headcount: 5,
  payAmount: 650,
  requiredCompetencyIds: ['picking-basics'],
  description: 'Evening picking shift.',
  supervisorName: 'Ramesh',
  supervisorContact: '+91-90000-00000',
  cancellationPolicy: 'Cancel up to 2 hours before start.',
};

describe('EmployerShiftsService.createDraft', () => {
  it('creates a draft shift with a generated check-in code', async () => {
    const admin = new FakeSupabaseAdmin();
    const service = buildService(admin);

    const shift = await service.createDraft('employer-1', draftInput);

    expect(shift.status).toBe('draft');
    expect(shift.checkInCode).toMatch(/^\d{6}$/);
    expect(admin.shiftsTable.rows).toHaveLength(1);
    expect(admin.shiftsTable.rows[0]).toMatchObject({ employer_id: 'employer-1' });
  });
});

describe('EmployerShiftsService.publish', () => {
  it('publishes a draft shift owned by the calling employer', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.shiftsTable.rows = [
      {
        id: 'shift-1',
        employer_id: 'employer-1',
        role_title: 'Picker / Packer',
        site_name: 'Dark store',
        site_address: '1 Main Rd',
        city: 'Bengaluru',
        starts_at: 't1',
        ends_at: 't2',
        reporting_time: null,
        headcount: 5,
        pay_amount: 650,
        pay_currency: 'INR',
        required_competency_ids: [],
        description: null,
        supervisor_name: null,
        supervisor_contact: null,
        cancellation_policy: null,
        check_in_code: '123456',
        status: 'draft',
      },
    ];
    const service = buildService(admin);

    const shift = await service.publish('employer-1', 'shift-1');

    expect(shift.status).toBe('published');
  });

  it("denies publishing another employer's shift (indistinguishable from not found)", async () => {
    const admin = new FakeSupabaseAdmin();
    admin.shiftsTable.rows = [
      {
        id: 'shift-1',
        employer_id: 'employer-A',
        role_title: 'Picker / Packer',
        site_name: 'Dark store',
        site_address: '1 Main Rd',
        city: 'Bengaluru',
        starts_at: 't1',
        ends_at: 't2',
        reporting_time: null,
        headcount: 5,
        pay_amount: 650,
        pay_currency: 'INR',
        required_competency_ids: [],
        description: null,
        supervisor_name: null,
        supervisor_contact: null,
        cancellation_policy: null,
        check_in_code: '123456',
        status: 'draft',
      },
    ];
    const service = buildService(admin);

    await expect(
      service.publish('employer-B', 'shift-1'),
    ).rejects.toMatchObject({ code: 'SHIFT_NOT_FOUND' });
    expect(admin.shiftsTable.rows[0].status).toBe('draft');
  });
});

describe('EmployerShiftsService.listOwn', () => {
  it("lists only this employer's shifts and counts non-cancelled applications", async () => {
    const admin = new FakeSupabaseAdmin();
    admin.shiftsTable.rows = [
      {
        id: 'shift-1',
        employer_id: 'employer-1',
        role_title: 'Picker / Packer',
        site_name: 'Dark store',
        site_address: '1 Main Rd',
        city: 'Bengaluru',
        starts_at: 't1',
        ends_at: 't2',
        reporting_time: null,
        headcount: 5,
        pay_amount: 650,
        pay_currency: 'INR',
        required_competency_ids: [],
        description: null,
        supervisor_name: null,
        supervisor_contact: null,
        cancellation_policy: null,
        check_in_code: '123456',
        status: 'published',
      },
      {
        id: 'shift-2',
        employer_id: 'employer-2',
        role_title: 'Loader',
        site_name: 'Warehouse',
        site_address: '2 Other Rd',
        city: 'Pune',
        starts_at: 't1',
        ends_at: 't2',
        reporting_time: null,
        headcount: 3,
        pay_amount: 500,
        pay_currency: 'INR',
        required_competency_ids: [],
        description: null,
        supervisor_name: null,
        supervisor_contact: null,
        cancellation_policy: null,
        check_in_code: '654321',
        status: 'published',
      },
    ];
    admin.applications = [
      { shift_id: 'shift-1', status: 'accepted' },
      { shift_id: 'shift-1', status: 'completed' },
      { shift_id: 'shift-1', status: 'cancelled' },
    ];
    const service = buildService(admin);

    const shifts = await service.listOwn('employer-1');

    expect(shifts.map((s) => s.id)).toEqual(['shift-1']);
    expect(shifts[0].applicationCount).toBe(2);
  });

  it('returns an empty list for an employer with no shifts', async () => {
    const admin = new FakeSupabaseAdmin();
    const service = buildService(admin);

    expect(await service.listOwn('employer-1')).toEqual([]);
  });
});
