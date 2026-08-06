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
  jobs?: CareerjetJob[];
}

/**
 * Careerjet public API (https://www.careerjet.com/partners/api/) --
 * self-serve affiliate id, GET search. Careerjet results don't carry a
 * stable numeric id in the documented schema, so `externalId` is derived
 * from a hash of the listing URL (stable across syncs as long as the URL
 * doesn't change). The exact `locale_code` for India (`en_IN` vs. a
 * regional fallback) was not verified against current Careerjet docs at
 * implementation time -- see docs/25's flagged uncertainty.
 */
export class CareerjetAdapter implements JobSourceAdapter {
  readonly key = 'careerjet';

  constructor(
    private readonly affiliateId: string | undefined,
    private readonly fetcher: HttpFetcher,
  ) {}

  async fetchJobs(): Promise<ExternalJobListing[]> {
    if (!this.affiliateId) return [];

    const url =
      'https://public-api.careerjet.net/search' +
      `?affid=${encodeURIComponent(this.affiliateId)}` +
      '&keywords=warehouse+logistics' +
      '&location=India' +
      '&locale_code=en_IN' +
      '&pagesize=50';

    const response = await this.fetcher(url);
    if (!response.ok) {
      throw new Error(
        `Careerjet request failed with status ${response.status}`,
      );
    }
    const body = (await response.json()) as CareerjetResponse;

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
