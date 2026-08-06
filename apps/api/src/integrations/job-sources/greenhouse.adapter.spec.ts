import { GreenhouseAdapter } from './greenhouse.adapter';
import { HttpFetcher } from './http-fetcher';

function fakeFetcher(body: unknown, ok = true, status = 200): HttpFetcher {
  return async () =>
    ({
      ok,
      status,
      json: async () => body,
    }) as Response;
}

describe('GreenhouseAdapter', () => {
  it('returns [] without calling the fetcher when the company list is empty', async () => {
    let called = false;
    const fetcher: HttpFetcher = async () => {
      called = true;
      return { ok: true, status: 200, json: async () => ({}) } as Response;
    };
    const adapter = new GreenhouseAdapter([], fetcher);

    expect(await adapter.fetchJobs()).toEqual([]);
    expect(called).toBe(false);
  });

  it('maps a successful response and namespaces externalId with the board token', async () => {
    const fetcher = fakeFetcher({
      jobs: [
        {
          id: 12345,
          title: 'Warehouse Associate',
          location: { name: 'Bhiwandi, Maharashtra' },
          content: '<p>Receiving and <b>put-away</b>.</p>',
          absolute_url: 'https://boards.greenhouse.io/acme/jobs/12345',
        },
      ],
    });
    const adapter = new GreenhouseAdapter(
      [{ displayName: 'Acme Corp', token: 'acme' }],
      fetcher,
    );

    const listings = await adapter.fetchJobs();

    // stripHtml replaces each tag with a space, so "<b>put-away</b>." comes
    // out as "put-away ." -- a cosmetic quirk of naive tag stripping, not a
    // functional bug for description text.
    expect(listings).toEqual([
      {
        externalId: 'acme:12345',
        employerName: 'Acme Corp',
        title: 'Warehouse Associate',
        location: 'Bhiwandi, Maharashtra',
        description: 'Receiving and put-away .',
        applyUrl: 'https://boards.greenhouse.io/acme/jobs/12345',
      },
    ]);
  });

  it('queries every configured company and skips malformed entries', async () => {
    const seen: string[] = [];
    const fetcher: HttpFetcher = async (url) => {
      seen.push(url as string);
      return {
        ok: true,
        status: 200,
        json: async () => ({ jobs: [null, {}] }),
      } as Response;
    };
    const adapter = new GreenhouseAdapter(
      [
        { displayName: 'Acme Corp', token: 'acme' },
        { displayName: 'Beta Logistics', token: 'beta' },
      ],
      fetcher,
    );

    const listings = await adapter.fetchJobs();

    expect(listings).toEqual([]);
    expect(seen).toHaveLength(2);
    expect(seen[0]).toContain('/boards/acme/');
    expect(seen[1]).toContain('/boards/beta/');
  });

  it('throws on a non-ok response', async () => {
    const fetcher = fakeFetcher({}, false, 404);
    const adapter = new GreenhouseAdapter(
      [{ displayName: 'Acme Corp', token: 'acme' }],
      fetcher,
    );

    await expect(adapter.fetchJobs()).rejects.toThrow(/status 404/);
  });
});
