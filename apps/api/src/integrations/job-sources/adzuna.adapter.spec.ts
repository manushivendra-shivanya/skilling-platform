import { AdzunaAdapter } from './adzuna.adapter';
import { HttpFetcher } from './http-fetcher';
import { SEARCH_QUERIES } from './search-queries.config';

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

  it('runs one request per SEARCH_QUERIES entry, with the term in the "what" param', async () => {
    const seenUrls: string[] = [];
    const fetcher: HttpFetcher = async (url) => {
      seenUrls.push(url as string);
      return {
        ok: true,
        status: 200,
        json: async () => ({ results: [] }),
      } as Response;
    };
    const adapter = new AdzunaAdapter('app-id', 'app-key', fetcher);

    await adapter.fetchJobs();

    expect(seenUrls).toHaveLength(SEARCH_QUERIES.length);
    for (const query of SEARCH_QUERIES) {
      expect(seenUrls.some((url) => url.includes(`what=${encodeURIComponent(query)}`))).toBe(
        true,
      );
    }
  });

  it('maps a successful response into ExternalJobListing[], parsing the real posting date', async () => {
    const fetcher = fakeFetcher({
      results: [
        {
          id: 'adz-1',
          title: 'Warehouse Associate',
          company: { display_name: 'Apex Consumer Products' },
          location: { display_name: 'Bhiwandi, Maharashtra' },
          description: 'Receiving and put-away.',
          redirect_url: 'https://adzuna.example/jobs/adz-1',
          created: '2026-07-17T15:57:47Z',
        },
      ],
    });
    const adapter = new AdzunaAdapter('app-id', 'app-key', fetcher);

    const listings = await adapter.fetchJobs();

    // Every query returns the same fixture job -- fetchAllQueries dedupes
    // by externalId, so this is still exactly one listing.
    expect(listings).toEqual([
      {
        externalId: 'adz-1',
        employerName: 'Apex Consumer Products',
        title: 'Warehouse Associate',
        location: 'Bhiwandi, Maharashtra',
        description: 'Receiving and put-away.',
        applyUrl: 'https://adzuna.example/jobs/adz-1',
        postedAt: '2026-07-17T15:57:47.000Z',
      },
    ]);
  });

  it('falls back to the current time when "created" is missing', async () => {
    const fetcher = fakeFetcher({
      results: [
        {
          id: 'adz-2',
          title: 'Warehouse Associate',
          redirect_url: 'https://adzuna.example/jobs/adz-2',
        },
      ],
    });
    const adapter = new AdzunaAdapter('app-id', 'app-key', fetcher);

    const [listing] = await adapter.fetchJobs();

    expect(() => new Date(listing.postedAt).toISOString()).not.toThrow();
    expect(Date.now() - new Date(listing.postedAt).getTime()).toBeLessThan(60_000);
  });

  it('skips results missing required fields rather than crashing the sync', async () => {
    const fetcher = fakeFetcher({
      results: [{ title: 'No id or url' }, null, {}],
    });
    const adapter = new AdzunaAdapter('app-id', 'app-key', fetcher);

    const listings = await adapter.fetchJobs();

    expect(listings).toEqual([]);
  });

  it('throws on a non-ok response for every query', async () => {
    const fetcher = fakeFetcher({}, false, 500);
    const adapter = new AdzunaAdapter('app-id', 'app-key', fetcher);

    await expect(adapter.fetchJobs()).rejects.toThrow(/All queries failed/);
  });
});
