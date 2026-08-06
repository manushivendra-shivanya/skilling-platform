import { JoobleAdapter } from './jooble.adapter';
import { HttpFetcher } from './http-fetcher';

function fakeFetcher(body: unknown, ok = true, status = 200): HttpFetcher {
  return async () =>
    ({
      ok,
      status,
      json: async () => body,
    }) as Response;
}

describe('JoobleAdapter', () => {
  it('returns [] without calling the fetcher when the api key is missing', async () => {
    let called = false;
    const fetcher: HttpFetcher = async () => {
      called = true;
      return { ok: true, status: 200, json: async () => ({}) } as Response;
    };
    const adapter = new JoobleAdapter(undefined, fetcher);

    expect(await adapter.fetchJobs()).toEqual([]);
    expect(called).toBe(false);
  });

  it('maps a successful response, using the provided id when present', async () => {
    const fetcher = fakeFetcher({
      jobs: [
        {
          id: 42,
          title: 'Inventory Executive',
          company: 'Meridian Logistics',
          location: 'Gurugram, Haryana',
          snippet: 'Cycle counts and stock accuracy.',
          link: 'https://jooble.example/jobs/42',
        },
      ],
    });
    const adapter = new JoobleAdapter('api-key', fetcher);

    const listings = await adapter.fetchJobs();

    expect(listings).toEqual([
      {
        externalId: '42',
        employerName: 'Meridian Logistics',
        title: 'Inventory Executive',
        location: 'Gurugram, Haryana',
        description: 'Cycle counts and stock accuracy.',
        applyUrl: 'https://jooble.example/jobs/42',
      },
    ]);
  });

  it('derives a stable id from the link when no id is provided', async () => {
    const fetcher = fakeFetcher({
      jobs: [
        {
          title: 'Dispatch Executive',
          link: 'https://jooble.example/jobs/no-id',
        },
      ],
    });
    const adapter = new JoobleAdapter('api-key', fetcher);

    const [listing] = await adapter.fetchJobs();

    expect(listing.externalId).toMatch(/^[a-f0-9]{64}$/);
  });

  it('skips malformed entries rather than crashing the sync', async () => {
    const fetcher = fakeFetcher({ jobs: [null, {}, { title: 'No link' }] });
    const adapter = new JoobleAdapter('api-key', fetcher);

    expect(await adapter.fetchJobs()).toEqual([]);
  });

  it('throws on a non-ok response', async () => {
    const fetcher = fakeFetcher({}, false, 503);
    const adapter = new JoobleAdapter('api-key', fetcher);

    await expect(adapter.fetchJobs()).rejects.toThrow(/status 503/);
  });
});
