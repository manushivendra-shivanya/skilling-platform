import { CareerjetAdapter } from './careerjet.adapter';
import { HttpFetcher } from './http-fetcher';

function fakeFetcher(body: unknown, ok = true, status = 200): HttpFetcher {
  return async () =>
    ({
      ok,
      status,
      json: async () => body,
    }) as Response;
}

describe('CareerjetAdapter', () => {
  it('returns [] without calling the fetcher when the affiliate id is missing', async () => {
    let called = false;
    const fetcher: HttpFetcher = async () => {
      called = true;
      return { ok: true, status: 200, json: async () => ({}) } as Response;
    };
    const adapter = new CareerjetAdapter(undefined, fetcher);

    expect(await adapter.fetchJobs()).toEqual([]);
    expect(called).toBe(false);
  });

  it('maps a successful response, deriving externalId from the listing url', async () => {
    const fetcher = fakeFetcher({
      jobs: [
        {
          title: 'Dispatch Executive',
          company: 'Northstar Freight',
          locations: 'Pune, Maharashtra',
          description: 'Prioritise outbound dispatch against SLAs.',
          url: 'https://careerjet.example/jobs/1',
        },
      ],
    });
    const adapter = new CareerjetAdapter('affid-1', fetcher);

    const listings = await adapter.fetchJobs();

    expect(listings).toHaveLength(1);
    expect(listings[0]).toMatchObject({
      employerName: 'Northstar Freight',
      title: 'Dispatch Executive',
      location: 'Pune, Maharashtra',
      description: 'Prioritise outbound dispatch against SLAs.',
      applyUrl: 'https://careerjet.example/jobs/1',
    });
    expect(listings[0].externalId).toMatch(/^[a-f0-9]{64}$/);
  });

  it('skips malformed entries rather than crashing the sync', async () => {
    const fetcher = fakeFetcher({ jobs: [null, {}, { title: 'No url' }] });
    const adapter = new CareerjetAdapter('affid-1', fetcher);

    expect(await adapter.fetchJobs()).toEqual([]);
  });

  it('throws on a non-ok response', async () => {
    const fetcher = fakeFetcher({}, false, 502);
    const adapter = new CareerjetAdapter('affid-1', fetcher);

    await expect(adapter.fetchJobs()).rejects.toThrow(/status 502/);
  });
});
