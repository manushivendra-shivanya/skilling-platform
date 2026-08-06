import { AdzunaAdapter } from './adzuna.adapter';
import { HttpFetcher } from './http-fetcher';

function fakeFetcher(body: unknown, ok = true, status = 200): HttpFetcher {
  return async () =>
    ({
      ok,
      status,
      json: async () => body,
    }) as Response;
}

describe('AdzunaAdapter', () => {
  it('returns [] without calling the fetcher when app id/key are missing', async () => {
    let called = false;
    const fetcher: HttpFetcher = async () => {
      called = true;
      return { ok: true, status: 200, json: async () => ({}) } as Response;
    };
    const adapter = new AdzunaAdapter(undefined, undefined, fetcher);

    const listings = await adapter.fetchJobs();

    expect(listings).toEqual([]);
    expect(called).toBe(false);
  });

  it('maps a successful response into ExternalJobListing[]', async () => {
    const fetcher = fakeFetcher({
      results: [
        {
          id: 'adz-1',
          title: 'Warehouse Associate',
          company: { display_name: 'Apex Consumer Products' },
          location: { display_name: 'Bhiwandi, Maharashtra' },
          description: 'Receiving and put-away.',
          redirect_url: 'https://adzuna.example/jobs/adz-1',
        },
      ],
    });
    const adapter = new AdzunaAdapter('app-id', 'app-key', fetcher);

    const listings = await adapter.fetchJobs();

    expect(listings).toEqual([
      {
        externalId: 'adz-1',
        employerName: 'Apex Consumer Products',
        title: 'Warehouse Associate',
        location: 'Bhiwandi, Maharashtra',
        description: 'Receiving and put-away.',
        applyUrl: 'https://adzuna.example/jobs/adz-1',
      },
    ]);
  });

  it('skips results missing required fields rather than crashing the sync', async () => {
    const fetcher = fakeFetcher({
      results: [{ title: 'No id or url' }, null, {}],
    });
    const adapter = new AdzunaAdapter('app-id', 'app-key', fetcher);

    const listings = await adapter.fetchJobs();

    expect(listings).toEqual([]);
  });

  it('throws on a non-ok response', async () => {
    const fetcher = fakeFetcher({}, false, 500);
    const adapter = new AdzunaAdapter('app-id', 'app-key', fetcher);

    await expect(adapter.fetchJobs()).rejects.toThrow(/status 500/);
  });
});
