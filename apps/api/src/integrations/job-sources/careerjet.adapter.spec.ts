import { CareerjetAdapter } from './careerjet.adapter';
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

describe('CareerjetAdapter', () => {
  it('returns [] without calling the fetcher when the API key is missing', async () => {
    let called = false;
    const fetcher: HttpFetcher = async () => {
      called = true;
      return { ok: true, status: 200, json: async () => ({}) } as Response;
    };
    const adapter = new CareerjetAdapter(undefined, fetcher);

    expect(await adapter.fetchJobs()).toEqual([]);
    expect(called).toBe(false);
  });

  it('sends the API key as HTTP Basic auth (key + empty password, base64-encoded)', async () => {
    let seenAuthHeader: string | undefined;
    const fetcher: HttpFetcher = async (_url, init) => {
      seenAuthHeader = (init?.headers as Record<string, string>)
        ?.Authorization;
      return {
        ok: true,
        status: 200,
        json: async () => ({ type: 'JOBS', jobs: [] }),
      } as Response;
    };
    const adapter = new CareerjetAdapter('my-api-key', fetcher);

    await adapter.fetchJobs();

    const expected = `Basic ${Buffer.from('my-api-key:').toString('base64')}`;
    expect(seenAuthHeader).toBe(expected);
  });

  it('runs one request per SEARCH_QUERIES entry, sending the term as "keywords"', async () => {
    const seenUrls: string[] = [];
    const fetcher: HttpFetcher = async (url) => {
      seenUrls.push(url as string);
      return {
        ok: true,
        status: 200,
        json: async () => ({ type: 'JOBS', jobs: [] }),
      } as Response;
    };
    const adapter = new CareerjetAdapter('api-key-1', fetcher);

    await adapter.fetchJobs();

    expect(seenUrls).toHaveLength(SEARCH_QUERIES.length);
    for (const query of SEARCH_QUERIES) {
      expect(
        seenUrls.some((url) => url.includes(`keywords=${encodeURIComponent(query)}`)),
      ).toBe(true);
    }
  });

  it('maps a successful response, deriving externalId from the listing url and parsing the real posting date', async () => {
    const fetcher = fakeFetcher({
      type: 'JOBS',
      jobs: [
        {
          title: 'Dispatch Executive',
          company: 'Northstar Freight',
          locations: 'Pune, Maharashtra',
          description: 'Prioritise outbound dispatch against SLAs.',
          url: 'https://careerjet.example/jobs/1',
          date: 'Wed,15 Nov 2025 19:13:43 GMT',
        },
      ],
    });
    const adapter = new CareerjetAdapter('api-key-1', fetcher);

    const listings = await adapter.fetchJobs();

    expect(listings).toHaveLength(1);
    expect(listings[0]).toMatchObject({
      employerName: 'Northstar Freight',
      title: 'Dispatch Executive',
      location: 'Pune, Maharashtra',
      description: 'Prioritise outbound dispatch against SLAs.',
      applyUrl: 'https://careerjet.example/jobs/1',
      postedAt: '2025-11-15T19:13:43.000Z',
    });
    expect(listings[0].externalId).toMatch(/^[a-f0-9]{64}$/);
  });

  it('returns [] on a "location mode" response (no matching/ambiguous location)', async () => {
    const fetcher = fakeFetcher({
      type: 'LOCATIONS',
      locations: [],
      message: 'no matching location found',
    });
    const adapter = new CareerjetAdapter('api-key-1', fetcher);

    expect(await adapter.fetchJobs()).toEqual([]);
  });

  it('skips malformed entries rather than crashing the sync', async () => {
    const fetcher = fakeFetcher({
      type: 'JOBS',
      jobs: [null, {}, { title: 'No url' }],
    });
    const adapter = new CareerjetAdapter('api-key-1', fetcher);

    expect(await adapter.fetchJobs()).toEqual([]);
  });

  it('throws when every query gets a non-ok response', async () => {
    const fetcher = fakeFetcher({}, false, 502);
    const adapter = new CareerjetAdapter('api-key-1', fetcher);

    await expect(adapter.fetchJobs()).rejects.toThrow(/All queries failed/);
  });
});
