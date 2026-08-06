import { fetchAllQueries } from './multi-query';
import { ExternalJobListing } from './job-source-adapter';

function listing(externalId: string, title = 'Warehouse Associate'): ExternalJobListing {
  return {
    externalId,
    employerName: 'Acme Corp',
    title,
    location: 'Bhiwandi, Maharashtra',
    description: 'Receiving and put-away.',
    applyUrl: `https://example.com/jobs/${externalId}`,
    postedAt: '2026-08-01T00:00:00.000Z',
  };
}

describe('fetchAllQueries', () => {
  it('calls fetchOne once per query and concatenates the results', async () => {
    const calls: string[] = [];
    const results = await fetchAllQueries(['a', 'b', 'c'], async (query) => {
      calls.push(query);
      return [listing(`${query}-1`)];
    });

    expect(calls).toEqual(['a', 'b', 'c']);
    expect(results.map((r) => r.externalId).sort()).toEqual(['a-1', 'b-1', 'c-1']);
  });

  it('dedupes listings that share an externalId across different queries', async () => {
    const results = await fetchAllQueries(['warehouse', 'Acme Corp'], async (query) =>
      // Same real job matches both queries -- same externalId either way.
      query === 'warehouse' ? [listing('shared-1', 'Warehouse Associate')] : [listing('shared-1', 'Warehouse Associate')],
    );

    expect(results).toHaveLength(1);
    expect(results[0].externalId).toBe('shared-1');
  });

  it('tolerates one query failing as long as another succeeds', async () => {
    const results = await fetchAllQueries(['bad', 'good'], async (query) => {
      if (query === 'bad') throw new Error('boom');
      return [listing('good-1')];
    });

    expect(results).toEqual([listing('good-1')]);
  });

  it('throws only when every single query fails', async () => {
    await expect(
      fetchAllQueries(['bad1', 'bad2'], async () => {
        throw new Error('boom');
      }),
    ).rejects.toThrow(/All queries failed/);
  });

  it('returns [] for an empty query list without calling fetchOne', async () => {
    let called = false;
    const results = await fetchAllQueries([], async () => {
      called = true;
      return [];
    });

    expect(results).toEqual([]);
    expect(called).toBe(false);
  });
});
