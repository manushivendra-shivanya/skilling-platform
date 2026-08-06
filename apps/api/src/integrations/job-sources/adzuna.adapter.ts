import { ExternalJobListing, JobSourceAdapter } from './job-source-adapter';
import { HttpFetcher } from './http-fetcher';
import { fetchAllQueries } from './multi-query';
import { parsePostedAt } from './parse-posted-at';
import { SEARCH_QUERIES } from './search-queries.config';

interface AdzunaResult {
  id?: string;
  title?: string;
  company?: { display_name?: string };
  location?: { display_name?: string };
  description?: string;
  redirect_url?: string;
  created?: string;
}

interface AdzunaResponse {
  results?: AdzunaResult[];
}

/**
 * Adzuna Job Search API (https://developer.adzuna.com/) -- self-serve
 * app_id/app_key, India index. Runs one request per term in
 * `SEARCH_QUERIES` (see that file for why it's a curated list, not one
 * fixed phrase) -- confirmed live that a single generic "warehouse
 * logistics" query missed genuine listings from real logistics employers
 * (e.g. Delhivery's "Director - Hub Operations") that only surfaced under
 * a company-name query, since Adzuna ranks by relevance to the literal
 * query text and only the first page was being fetched.
 */
export class AdzunaAdapter implements JobSourceAdapter {
  readonly key = 'adzuna';

  constructor(
    private readonly appId: string | undefined,
    private readonly appKey: string | undefined,
    private readonly fetcher: HttpFetcher,
  ) {}

  async fetchJobs(): Promise<ExternalJobListing[]> {
    if (!this.appId || !this.appKey) return [];
    return fetchAllQueries(SEARCH_QUERIES, (query) => this.fetchOneQuery(query));
  }

  private async fetchOneQuery(query: string): Promise<ExternalJobListing[]> {
    const url =
      'https://api.adzuna.com/v1/api/jobs/in/search/1' +
      `?app_id=${encodeURIComponent(this.appId!)}` +
      `&app_key=${encodeURIComponent(this.appKey!)}` +
      '&results_per_page=50' +
      `&what=${encodeURIComponent(query)}` +
      '&content-type=application/json';

    const response = await this.fetcher(url);
    if (!response.ok) {
      throw new Error(`Adzuna request failed with status ${response.status}`);
    }
    const body = (await response.json()) as AdzunaResponse;

    const listings: ExternalJobListing[] = [];
    for (const result of body.results ?? []) {
      if (!result?.id || !result.title || !result.redirect_url) continue;
      listings.push({
        externalId: result.id,
        employerName: result.company?.display_name ?? 'Unknown employer',
        title: result.title,
        location: result.location?.display_name ?? 'Location not specified',
        description: result.description ?? '',
        applyUrl: result.redirect_url,
        postedAt: parsePostedAt(result.created),
      });
    }
    return listings;
  }
}
