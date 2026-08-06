import { createHash } from 'crypto';
import { ExternalJobListing, JobSourceAdapter } from './job-source-adapter';
import { HttpFetcher } from './http-fetcher';

interface CareerjetJob {
  title?: string;
  company?: string;
  locations?: string;
  description?: string;
  url?: string;
}

interface CareerjetResponse {
  type?: string; // 'JOBS' | 'LOCATIONS'
  jobs?: CareerjetJob[];
}

/**
 * Careerjet API v4 (https://search.api.careerjet.net/v4/query) --
 * confirmed against Careerjet's own current documentation (an earlier
 * guess at the legacy `affid` query-param scheme returned `401 Unknown
 * publisher site` with an explicit "use the new endpoint" message; this
 * is that new endpoint).
 *
 * Auth is HTTP Basic: username is the API key, password is empty --
 * `Authorization: Basic base64(apiKey + ':')`. `user_ip`/`user_agent` are
 * both required by Careerjet (403 if missing) -- the API is designed
 * around a real visitor's search action, which doesn't quite fit a
 * scheduled background sync; a generic service identity is sent instead
 * since there's no real end-user request to attribute this to.
 *
 * Careerjet job objects carry no stable id in the documented schema, so
 * `externalId` is derived from a hash of the listing URL. A "location
 * mode" response (`type: 'LOCATIONS'`, no `jobs` array) is possible if
 * the location parameter is ambiguous/unmatched -- treated the same as
 * an empty result set, not an error.
 */
export class CareerjetAdapter implements JobSourceAdapter {
  readonly key = 'careerjet';

  constructor(
    private readonly apiKey: string | undefined,
    private readonly fetcher: HttpFetcher,
  ) {}

  async fetchJobs(): Promise<ExternalJobListing[]> {
    if (!this.apiKey) return [];

    const url =
      'https://search.api.careerjet.net/v4/query' +
      '?keywords=warehouse%20logistics' +
      '&location=India' +
      '&locale_code=en_IN' +
      '&page_size=50' +
      '&user_ip=0.0.0.0' +
      '&user_agent=FloraJobSync%2F1.0';

    const credentials = Buffer.from(`${this.apiKey}:`).toString('base64');
    const response = await this.fetcher(url, {
      headers: { Authorization: `Basic ${credentials}` },
    });
    if (!response.ok) {
      throw new Error(
        `Careerjet request failed with status ${response.status}`,
      );
    }
    const body = (await response.json()) as CareerjetResponse;
    if (body.type !== 'JOBS') return [];

    const listings: ExternalJobListing[] = [];
    for (const job of body.jobs ?? []) {
      if (!job?.title || !job.url) continue;
      listings.push({
        externalId: createHash('sha256').update(job.url).digest('hex'),
        employerName: job.company ?? 'Unknown employer',
        title: job.title,
        location: job.locations ?? 'Location not specified',
        description: job.description ?? '',
        applyUrl: job.url,
      });
    }
    return listings;
  }
}
