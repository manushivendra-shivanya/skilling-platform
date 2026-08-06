import { LeverAdapter } from './lever.adapter';
import { HttpFetcher } from './http-fetcher';

function fakeFetcher(body: unknown, ok = true, status = 200): HttpFetcher {
  return async () =>
    ({
      ok,
      status,
      json: async () => body,
    }) as Response;
}

describe('LeverAdapter', () => {
  it('returns [] without calling the fetcher when the company list is empty', async () => {
    let called = false;
    const fetcher: HttpFetcher = async () => {
      called = true;
      return { ok: true, status: 200, json: async () => [] } as Response;
    };
    const adapter = new LeverAdapter([], fetcher);

    expect(await adapter.fetchJobs()).toEqual([]);
    expect(called).toBe(false);
  });

  it('maps a successful response (a bare array), namespaces externalId, and converts the Unix-ms createdAt to ISO', async () => {
    const fetcher = fakeFetcher([
      {
        id: 'posting-1',
        text: 'Inventory Executive',
        categories: { location: 'Gurugram, Haryana' },
        descriptionPlain: 'Cycle counts and reconciliation.',
        hostedUrl: 'https://jobs.lever.co/acme/posting-1',
        createdAt: 1757916149833,
      },
    ]);
    const adapter = new LeverAdapter(
      [{ displayName: 'Acme Corp', token: 'acme' }],
      fetcher,
    );

    const listings = await adapter.fetchJobs();

    expect(listings).toEqual([
      {
        externalId: 'acme:posting-1',
        employerName: 'Acme Corp',
        title: 'Inventory Executive',
        location: 'Gurugram, Haryana',
        description: 'Cycle counts and reconciliation.',
        applyUrl: 'https://jobs.lever.co/acme/posting-1',
        postedAt: new Date(1757916149833).toISOString(),
      },
    ]);
  });

  it('falls back to a stripped HTML description when descriptionPlain is absent', async () => {
    const fetcher = fakeFetcher([
      {
        id: 'posting-2',
        text: 'Dispatch Executive',
        description: '<p>Prioritise <b>outbound</b> dispatch.</p>',
        hostedUrl: 'https://jobs.lever.co/acme/posting-2',
      },
    ]);
    const adapter = new LeverAdapter(
      [{ displayName: 'Acme Corp', token: 'acme' }],
      fetcher,
    );

    const [listing] = await adapter.fetchJobs();

    expect(listing.description).toBe('Prioritise outbound dispatch.');
  });

  it('skips malformed entries rather than crashing the sync', async () => {
    const fetcher = fakeFetcher([null, {}, { text: 'No id or url' }]);
    const adapter = new LeverAdapter(
      [{ displayName: 'Acme Corp', token: 'acme' }],
      fetcher,
    );

    expect(await adapter.fetchJobs()).toEqual([]);
  });

  it('throws on a non-ok response', async () => {
    const fetcher = fakeFetcher([], false, 500);
    const adapter = new LeverAdapter(
      [{ displayName: 'Acme Corp', token: 'acme' }],
      fetcher,
    );

    await expect(adapter.fetchJobs()).rejects.toThrow(/status 500/);
  });
});
