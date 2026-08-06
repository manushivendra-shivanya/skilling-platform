import { ExternalJobListing } from './job-source-adapter';

/**
 * Runs `fetchOne` once per query term, tolerating individual query
 * failures rather than letting one bad query drop every other query's
 * results -- "even 1 extra job is important" means a transient failure on
 * query 3 of 8 shouldn't cost the successful results from the other 7.
 * Only throws if every single query failed (nothing at all came back),
 * so JobSyncService's per-adapter failure isolation still sees a genuine
 * "this source is broken" signal rather than silently returning [] and
 * looking identical to "not configured".
 */
export async function fetchAllQueries(
  queries: string[],
  fetchOne: (query: string) => Promise<ExternalJobListing[]>,
): Promise<ExternalJobListing[]> {
  const results: ExternalJobListing[] = [];
  const errors: string[] = [];
  for (const query of queries) {
    try {
      results.push(...(await fetchOne(query)));
    } catch (error) {
      errors.push(
        `"${query}": ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }
  if (results.length === 0 && errors.length > 0) {
    throw new Error(`All queries failed: ${errors.join('; ')}`);
  }
  return dedupeByExternalId(results);
}

/**
 * The same real job commonly matches more than one query term (e.g. both
 * "warehouse logistics" and a company-name query) -- collapse to one
 * listing per externalId before it ever reaches the upsert, since the
 * upsert would otherwise just overwrite the same row multiple times in
 * one sync for no benefit.
 */
function dedupeByExternalId(
  listings: ExternalJobListing[],
): ExternalJobListing[] {
  const seen = new Map<string, ExternalJobListing>();
  for (const listing of listings) seen.set(listing.externalId, listing);
  return [...seen.values()];
}
