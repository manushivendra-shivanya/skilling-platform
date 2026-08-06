import { ExternalJobListing, JobSourceAdapter } from './job-source-adapter';
import { HttpFetcher } from './http-fetcher';

interface AdzunaResult {
  id?: string;
  title?: string;
  company?: { display_name?: string };
  location?: { display_name?: string };
  description?: string;
  redirect_url?: string;
}

interface AdzunaResponse {
  results?: AdzunaResult[];
}

/**
 * Adzuna Job Search API (https://developer.adzuna.com/) -- self-serve
 * app_id/app_key, India index, warehouse/logistics keyword search.
 * Exact category taxonomy for logistics/warehouse roles was not verified
 * against current Adzuna docs at implementation time (see
 * docs/25-job-sourcing-voice-ai-career-progression-plan.md's flagged
 * uncertainty) -- this uses a plain free-text `what` query, which is
 * always supported, rather than assuming a specific category slug.
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

    const url =
      'https://api.adzuna.com/v1/api/jobs/in/search/1' +
      `?app_id=${encodeURIComponent(this.appId)}` +
      `&app_key=${encodeURIComponent(this.appKey)}` +
      '&results_per_page=50' +
      '&what=warehouse%20logistics' +
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
      });
    }
    return listings;
  }
}
