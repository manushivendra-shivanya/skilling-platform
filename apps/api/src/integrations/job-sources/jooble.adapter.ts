import { createHash } from 'crypto';
import { ExternalJobListing, JobSourceAdapter } from './job-source-adapter';
import { HttpFetcher } from './http-fetcher';

interface JoobleJob {
  id?: string | number;
  title?: string;
  company?: string;
  location?: string;
  snippet?: string;
  link?: string;
}

interface JoobleResponse {
  jobs?: JoobleJob[];
}

/**
 * Jooble API (https://jooble.org/api/about) -- self-serve single API key,
 * POST-based search. Jooble's documented response schema hasn't always
 * carried a stable `id` on every result; when it's missing, fall back to a
 * hash of the listing URL rather than dropping the job or inventing a
 * fragile ordinal id (see docs/25's flagged uncertainty -- verify the
 * current schema against Jooble's docs at implementation time).
 */
export class JoobleAdapter implements JobSourceAdapter {
  readonly key = 'jooble';

  constructor(
    private readonly apiKey: string | undefined,
    private readonly fetcher: HttpFetcher,
  ) {}

  async fetchJobs(): Promise<ExternalJobListing[]> {
    if (!this.apiKey) return [];

    const url = `https://jooble.org/api/${encodeURIComponent(this.apiKey)}`;
    const response = await this.fetcher(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        keywords: 'warehouse logistics',
        location: 'India',
      }),
    });
    if (!response.ok) {
      throw new Error(`Jooble request failed with status ${response.status}`);
    }
    const body = (await response.json()) as JoobleResponse;

    const listings: ExternalJobListing[] = [];
    for (const job of body.jobs ?? []) {
      if (!job?.title || !job.link) continue;
      const externalId =
        job.id != null
          ? String(job.id)
          : createHash('sha256').update(job.link).digest('hex');
      listings.push({
        externalId,
        employerName: job.company ?? 'Unknown employer',
        title: job.title,
        location: job.location ?? 'Location not specified',
        description: job.snippet ?? '',
        applyUrl: job.link,
      });
    }
    return listings;
  }
}
