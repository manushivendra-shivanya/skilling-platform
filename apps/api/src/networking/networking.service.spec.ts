import { NetworkingService } from './networking.service';
import { SupabaseService } from '../supabase/supabase.service';

type Row = Record<string, unknown>;

/**
 * Minimal in-memory Postgres-ish store supporting exactly the operations
 * NetworkingService actually calls (select/eq/in/maybeSingle/then,
 * insert, update, upsert, delete) -- same spirit as
 * career-passport.service.spec.ts's fake query builder, extended with
 * mutations since this service, unlike CareerPassportService, writes.
 */
class Query {
  private filters: Array<(row: Row) => boolean> = [];

  constructor(
    private readonly store: { rows: Row[] },
    private readonly op:
      | { kind: 'select' }
      | { kind: 'insert'; row: Row }
      | { kind: 'update'; patch: Row }
      | { kind: 'upsert'; row: Row; conflictKeys: string[] }
      | { kind: 'delete' },
  ) {}

  // Accepts (and ignores) the column-selection string real supabase-js
  // takes -- this fake always returns full rows; tests only assert on
  // the fields they set.
  select(cols?: string): this {
    void cols;
    return this;
  }

  eq(key: string, value: unknown): this {
    this.filters.push((row) => row[key] === value);
    return this;
  }

  in(key: string, values: unknown[]): this {
    this.filters.push((row) => values.includes(row[key]));
    return this;
  }

  private matched(): Row[] {
    return this.store.rows.filter((row) => this.filters.every((f) => f(row)));
  }

  private run(): Row[] {
    // Captured to a local so TypeScript can narrow by `op.kind` inside
    // each case -- narrowing a `this.op` property access directly
    // doesn't work the same way across a switch.
    const op = this.op;
    switch (op.kind) {
      case 'select':
        return this.matched();
      case 'insert': {
        const row = { id: `generated-${this.store.rows.length + 1}`, ...op.row };
        this.store.rows.push(row);
        return [row];
      }
      case 'update': {
        const targets = this.matched();
        targets.forEach((row) => Object.assign(row, op.patch));
        return targets;
      }
      case 'upsert': {
        const existing = this.store.rows.find((row) =>
          op.conflictKeys.every((key) => row[key] === op.row[key]),
        );
        if (existing) {
          Object.assign(existing, op.row);
          return [existing];
        }
        const row = { ...op.row };
        this.store.rows.push(row);
        return [row];
      }
      case 'delete': {
        const targets = this.matched();
        this.store.rows = this.store.rows.filter((row) => !targets.includes(row));
        return targets;
      }
    }
  }

  async maybeSingle() {
    return { data: this.run()[0] ?? null, error: null };
  }

  // Makes a bare `await query` (no .maybeSingle()) resolve the same way a
  // real supabase-js query thenable does.
  then(resolve: (result: { data: Row[]; error: null }) => void) {
    resolve({ data: this.run(), error: null });
  }
}

class FakeTable {
  private readonly store: { rows: Row[] } = { rows: [] };

  constructor(
    private readonly conflictKeys: string[] = ['id'],
    private readonly insertDefaults: Row = {},
  ) {}

  get rows(): Row[] {
    return this.store.rows;
  }
  set rows(value: Row[]) {
    this.store.rows = value;
  }

  select(cols?: string) {
    return new Query(this.store, { kind: 'select' }).select(cols);
  }
  insert(row: Row) {
    return new Query(this.store, { kind: 'insert', row: { ...this.insertDefaults, ...row } });
  }
  update(patch: Row) {
    return new Query(this.store, { kind: 'update', patch });
  }
  upsert(row: Row) {
    return new Query(this.store, {
      kind: 'upsert',
      row,
      conflictKeys: this.conflictKeys,
    });
  }
  delete() {
    return new Query(this.store, { kind: 'delete' });
  }
}

class FakeSupabaseAdmin {
  profiles = new FakeTable(['candidate_id']);
  connections = new FakeTable(['id'], {
    created_at: '2026-08-12T00:00:00.000Z',
    responded_at: null,
  });
  blocks = new FakeTable(['blocker_id', 'blocked_id']);

  from(table: string) {
    if (table === 'networking_profiles') return this.profiles;
    if (table === 'networking_connections') return this.connections;
    if (table === 'networking_blocks') return this.blocks;
    throw new Error(`Unhandled table in fake: ${table}`);
  }
}

function buildService(admin: FakeSupabaseAdmin): NetworkingService {
  const supabase = { admin } as unknown as SupabaseService;
  return new NetworkingService(supabase);
}

function seedProfile(
  admin: FakeSupabaseAdmin,
  overrides: Partial<{
    candidate_id: string;
    discoverable: boolean;
    full_name: string;
    headline: string;
    city: string;
    state: string;
    preferred_roles: string[];
  }>,
) {
  admin.profiles.rows.push({
    candidate_id: 'candidate-x',
    discoverable: true,
    full_name: 'Someone',
    headline: '',
    city: '',
    state: '',
    preferred_roles: [],
    ...overrides,
  });
}

describe('NetworkingService.getMyProfile', () => {
  it('returns all-defaults, not-discoverable when the candidate has never published', async () => {
    const service = buildService(new FakeSupabaseAdmin());

    const profile = await service.getMyProfile('candidate-1');

    expect(profile).toEqual({
      discoverable: false,
      fullName: '',
      headline: '',
      city: '',
      state: '',
      preferredRoles: [],
    });
  });

  it('returns the candidate own persisted row, including discoverable', async () => {
    const admin = new FakeSupabaseAdmin();
    seedProfile(admin, {
      candidate_id: 'candidate-1',
      discoverable: true,
      full_name: 'Asha Kumari',
      headline: 'Warehouse Associate',
      city: 'Lucknow',
      state: 'Uttar Pradesh',
      preferred_roles: ['warehouse_associate'],
    });
    const service = buildService(admin);

    const profile = await service.getMyProfile('candidate-1');

    expect(profile).toEqual({
      discoverable: true,
      fullName: 'Asha Kumari',
      headline: 'Warehouse Associate',
      city: 'Lucknow',
      state: 'Uttar Pradesh',
      preferredRoles: ['warehouse_associate'],
    });
  });
});

describe('NetworkingService.publishProfile', () => {
  it('rejects a blank name', async () => {
    const service = buildService(new FakeSupabaseAdmin());
    await expect(
      service.publishProfile('candidate-1', {
        fullName: '   ',
        preferredRoles: [],
        discoverable: true,
      }),
    ).rejects.toThrow('A name is required');
  });

  it('sanitizes and caps preferred roles, and upserts by candidate id', async () => {
    const admin = new FakeSupabaseAdmin();
    const service = buildService(admin);

    const response = await service.publishProfile('candidate-1', {
      fullName: '  Asha Kumari  ',
      headline: 'Warehouse Associate',
      city: 'Lucknow',
      state: 'Uttar Pradesh',
      preferredRoles: [
        'warehouse_associate',
        'warehouse_associate',
        '  inventory_executive  ',
        '',
      ],
      discoverable: true,
    });

    expect(response).toEqual({
      discoverable: true,
      fullName: 'Asha Kumari',
      headline: 'Warehouse Associate',
      city: 'Lucknow',
      state: 'Uttar Pradesh',
      preferredRoles: ['warehouse_associate', 'inventory_executive'],
    });
    expect(admin.profiles.rows).toHaveLength(1);

    // Publishing again updates the same row rather than creating a second.
    await service.publishProfile('candidate-1', {
      fullName: 'Asha Kumari',
      preferredRoles: [],
      discoverable: false,
    });
    expect(admin.profiles.rows).toHaveLength(1);
    expect(admin.profiles.rows[0].discoverable).toBe(false);
  });
});

describe('NetworkingService.discover', () => {
  it('requires the caller to have a discoverable profile of their own', async () => {
    const service = buildService(new FakeSupabaseAdmin());
    await expect(service.discover('candidate-1')).rejects.toThrow(
      'Turn on discoverability',
    );
  });

  it('returns only role-overlapping, non-excluded, non-self candidates', async () => {
    const admin = new FakeSupabaseAdmin();
    seedProfile(admin, {
      candidate_id: 'candidate-1',
      discoverable: true,
      preferred_roles: ['warehouse_associate'],
    });
    seedProfile(admin, {
      candidate_id: 'candidate-2',
      full_name: 'Ravi Singh',
      discoverable: true,
      preferred_roles: ['warehouse_associate', 'dispatch_executive'],
    });
    seedProfile(admin, {
      // Discoverable but no overlapping role -- excluded.
      candidate_id: 'candidate-3',
      full_name: 'No Overlap',
      discoverable: true,
      preferred_roles: ['dispatch_executive'],
    });
    seedProfile(admin, {
      // Overlapping role but not discoverable -- excluded.
      candidate_id: 'candidate-4',
      full_name: 'Not Discoverable',
      discoverable: false,
      preferred_roles: ['warehouse_associate'],
    });

    const service = buildService(admin);
    const results = await service.discover('candidate-1');

    expect(results).toEqual([
      {
        candidateId: 'candidate-2',
        fullName: 'Ravi Singh',
        headline: '',
        city: '',
        state: '',
        sharedRoles: ['warehouse_associate'],
      },
    ]);
  });

  it('excludes a candidate blocked in either direction', async () => {
    const admin = new FakeSupabaseAdmin();
    seedProfile(admin, {
      candidate_id: 'candidate-1',
      preferred_roles: ['warehouse_associate'],
    });
    seedProfile(admin, {
      candidate_id: 'candidate-2',
      preferred_roles: ['warehouse_associate'],
    });
    seedProfile(admin, {
      candidate_id: 'candidate-3',
      preferred_roles: ['warehouse_associate'],
    });
    admin.blocks.rows.push({ blocker_id: 'candidate-1', blocked_id: 'candidate-2' });
    admin.blocks.rows.push({ blocker_id: 'candidate-3', blocked_id: 'candidate-1' });

    const service = buildService(admin);
    expect(await service.discover('candidate-1')).toEqual([]);
  });

  it('excludes a candidate already connected or pending', async () => {
    const admin = new FakeSupabaseAdmin();
    seedProfile(admin, {
      candidate_id: 'candidate-1',
      preferred_roles: ['warehouse_associate'],
    });
    seedProfile(admin, {
      candidate_id: 'candidate-2',
      preferred_roles: ['warehouse_associate'],
    });
    admin.connections.rows.push({
      id: 'conn-1',
      requester_id: 'candidate-1',
      recipient_id: 'candidate-2',
      status: 'pending',
    });

    const service = buildService(admin);
    expect(await service.discover('candidate-1')).toEqual([]);
  });
});

describe('NetworkingService.sendConnectionRequest', () => {
  function seedTwoDiscoverable(admin: FakeSupabaseAdmin) {
    seedProfile(admin, { candidate_id: 'candidate-1', discoverable: true });
    seedProfile(admin, { candidate_id: 'candidate-2', discoverable: true });
  }

  it('rejects requesting yourself', async () => {
    const service = buildService(new FakeSupabaseAdmin());
    await expect(
      service.sendConnectionRequest('candidate-1', 'candidate-1'),
    ).rejects.toThrow('cannot send a connection request to yourself');
  });

  it('rejects when either side has blocked the other', async () => {
    const admin = new FakeSupabaseAdmin();
    seedTwoDiscoverable(admin);
    admin.blocks.rows.push({ blocker_id: 'candidate-2', blocked_id: 'candidate-1' });
    const service = buildService(admin);

    await expect(
      service.sendConnectionRequest('candidate-1', 'candidate-2'),
    ).rejects.toThrow('not available to connect');
  });

  it('rejects a non-discoverable recipient', async () => {
    const admin = new FakeSupabaseAdmin();
    seedProfile(admin, { candidate_id: 'candidate-1', discoverable: true });
    seedProfile(admin, { candidate_id: 'candidate-2', discoverable: false });
    const service = buildService(admin);

    await expect(
      service.sendConnectionRequest('candidate-1', 'candidate-2'),
    ).rejects.toThrow('not currently discoverable');
  });

  it('auto-accepts when the recipient already has a pending request to me', async () => {
    const admin = new FakeSupabaseAdmin();
    seedTwoDiscoverable(admin);
    admin.connections.rows.push({
      id: 'conn-1',
      requester_id: 'candidate-2',
      recipient_id: 'candidate-1',
      status: 'pending',
    });
    const service = buildService(admin);

    const result = await service.sendConnectionRequest('candidate-1', 'candidate-2');
    expect(result).toEqual({ id: 'conn-1', status: 'accepted' });
    expect(admin.connections.rows).toHaveLength(1);
    expect(admin.connections.rows[0].status).toBe('accepted');
  });

  it('rejects a duplicate outstanding request from the same requester', async () => {
    const admin = new FakeSupabaseAdmin();
    seedTwoDiscoverable(admin);
    admin.connections.rows.push({
      id: 'conn-1',
      requester_id: 'candidate-1',
      recipient_id: 'candidate-2',
      status: 'pending',
    });
    const service = buildService(admin);

    await expect(
      service.sendConnectionRequest('candidate-1', 'candidate-2'),
    ).rejects.toThrow('already have a pending request');
  });

  it('enforces a daily rate limit on outgoing requests', async () => {
    const admin = new FakeSupabaseAdmin();
    seedProfile(admin, { candidate_id: 'candidate-1', discoverable: true });
    for (let i = 0; i < 21; i += 1) {
      seedProfile(admin, {
        candidate_id: `candidate-recipient-${i}`,
        discoverable: true,
      });
    }
    const service = buildService(admin);

    for (let i = 0; i < 20; i += 1) {
      await service.sendConnectionRequest('candidate-1', `candidate-recipient-${i}`);
    }
    await expect(
      service.sendConnectionRequest('candidate-1', 'candidate-recipient-20'),
    ).rejects.toThrow("reached today's connection request limit");
  });
});

describe('NetworkingService.respondToConnection', () => {
  it('lets only the actual recipient accept or decline a pending request', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.connections.rows.push({
      id: 'conn-1',
      requester_id: 'candidate-1',
      recipient_id: 'candidate-2',
      status: 'pending',
    });
    const service = buildService(admin);

    await expect(
      service.respondToConnection('candidate-1', 'conn-1', true),
    ).rejects.toThrow('no longer available');

    const result = await service.respondToConnection('candidate-2', 'conn-1', true);
    expect(result).toEqual({ id: 'conn-1', status: 'accepted' });
  });

  it('rejects responding to an already-resolved request', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.connections.rows.push({
      id: 'conn-1',
      requester_id: 'candidate-1',
      recipient_id: 'candidate-2',
      status: 'declined',
    });
    const service = buildService(admin);

    await expect(
      service.respondToConnection('candidate-2', 'conn-1', true),
    ).rejects.toThrow('no longer available');
  });
});

describe('NetworkingService.withdrawConnection', () => {
  it('lets either party end an active connection', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.connections.rows.push({
      id: 'conn-1',
      requester_id: 'candidate-1',
      recipient_id: 'candidate-2',
      status: 'accepted',
    });
    const service = buildService(admin);

    const result = await service.withdrawConnection('candidate-2', 'conn-1');
    expect(result).toEqual({ id: 'conn-1', status: 'withdrawn' });
  });

  it('rejects a candidate who is not party to the connection', async () => {
    const admin = new FakeSupabaseAdmin();
    admin.connections.rows.push({
      id: 'conn-1',
      requester_id: 'candidate-1',
      recipient_id: 'candidate-2',
      status: 'accepted',
    });
    const service = buildService(admin);

    await expect(
      service.withdrawConnection('candidate-3', 'conn-1'),
    ).rejects.toThrow('no longer available');
  });
});

describe('NetworkingService.listConnections', () => {
  it('buckets connections into accepted, incoming, and outgoing, joined with the other candidate profile', async () => {
    const admin = new FakeSupabaseAdmin();
    seedProfile(admin, {
      candidate_id: 'candidate-2',
      full_name: 'Ravi Singh',
      headline: 'Dispatch Executive',
    });
    seedProfile(admin, {
      candidate_id: 'candidate-3',
      full_name: 'Priya Verma',
      headline: 'Inventory Executive',
    });
    seedProfile(admin, {
      candidate_id: 'candidate-4',
      full_name: 'Kiran Patel',
      headline: 'Warehouse Associate',
    });
    // Seeded with explicit created_at/responded_at -- rows pushed straight
    // onto the fake table (rather than via .insert()) skip FakeTable's
    // insertDefaults, and this is the one test that actually asserts on
    // those two fields.
    admin.connections.rows.push(
      {
        id: 'conn-accepted',
        requester_id: 'candidate-1',
        recipient_id: 'candidate-2',
        status: 'accepted',
        created_at: '2026-08-12T00:00:00.000Z',
        responded_at: null,
      },
      {
        id: 'conn-incoming',
        requester_id: 'candidate-3',
        recipient_id: 'candidate-1',
        status: 'pending',
        created_at: '2026-08-12T00:00:00.000Z',
        responded_at: null,
      },
      {
        id: 'conn-outgoing',
        requester_id: 'candidate-1',
        recipient_id: 'candidate-4',
        status: 'pending',
        created_at: '2026-08-12T00:00:00.000Z',
        responded_at: null,
      },
      {
        id: 'conn-declined',
        requester_id: 'candidate-1',
        recipient_id: 'candidate-2',
        status: 'declined',
        created_at: '2026-08-12T00:00:00.000Z',
        responded_at: null,
      },
    );
    const service = buildService(admin);

    const result = await service.listConnections('candidate-1');

    expect(result.accepted).toEqual([
      {
        id: 'conn-accepted',
        status: 'accepted',
        direction: 'outgoing',
        otherCandidateId: 'candidate-2',
        otherCandidate: {
          fullName: 'Ravi Singh',
          headline: 'Dispatch Executive',
          city: '',
          state: '',
        },
        createdAt: '2026-08-12T00:00:00.000Z',
        respondedAt: null,
      },
    ]);
    expect(result.incomingPending.map((c) => c.id)).toEqual(['conn-incoming']);
    expect(result.incomingPending[0].otherCandidate?.fullName).toBe('Priya Verma');
    expect(result.outgoingPending.map((c) => c.id)).toEqual(['conn-outgoing']);
    expect(result.outgoingPending[0].otherCandidate?.fullName).toBe('Kiran Patel');
  });
});

describe('NetworkingService blocking', () => {
  it('withdraws an existing active connection and prevents future requests', async () => {
    const admin = new FakeSupabaseAdmin();
    seedProfile(admin, { candidate_id: 'candidate-1', discoverable: true });
    seedProfile(admin, { candidate_id: 'candidate-2', discoverable: true });
    admin.connections.rows.push({
      id: 'conn-1',
      requester_id: 'candidate-1',
      recipient_id: 'candidate-2',
      status: 'accepted',
    });
    const service = buildService(admin);

    await service.blockCandidate('candidate-1', 'candidate-2');

    expect(admin.connections.rows[0].status).toBe('withdrawn');
    await expect(
      service.sendConnectionRequest('candidate-2', 'candidate-1'),
    ).rejects.toThrow('not available to connect');
  });

  it('unblocking removes the block', async () => {
    const admin = new FakeSupabaseAdmin();
    seedProfile(admin, { candidate_id: 'candidate-1', discoverable: true });
    seedProfile(admin, { candidate_id: 'candidate-2', discoverable: true });
    const service = buildService(admin);

    await service.blockCandidate('candidate-1', 'candidate-2');
    expect(admin.blocks.rows).toHaveLength(1);

    await service.unblockCandidate('candidate-1', 'candidate-2');
    expect(admin.blocks.rows).toHaveLength(0);

    // No longer blocked -- a request now goes through normally.
    const result = await service.sendConnectionRequest('candidate-2', 'candidate-1');
    expect(result.status).toBe('pending');
  });
});
