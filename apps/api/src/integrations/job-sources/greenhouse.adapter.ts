import { ExternalJobListing, JobSourceAdapter } from './job-source-adapter';
import { HttpFetcher } from './http-fetcher';
import { NamedCompanyConfig } from './named-companies.config';
import { stripHtml } from './strip-html';

interface GreenhouseJob {
  id?: number;
  title?: string;
  location?: { name?: string };
  content?: string;
  absolute_url?: string;
}

interface GreenhouseResponse {
  jobs?: GreenhouseJob[];
}

/**
 * Greenhouse's public job-board API (https://boards-api.greenhouse.io) --
 * no auth needed, but only returns jobs for one named company's board at
 * a time. Iterates `companies` (empty by default -- see
 * named-companies.config.ts) and namespaces `externalId` as
 * `${token}:${remoteId}` since Greenhouse ids are only unique within one
 * company's board, and every company synced through this adapter shares
 * the same `source` value.
 */
export class GreenhouseAdapter implements JobSourceAdapter {
  readonly key = 'greenhouse';

  constructor(
    private readonly companies: NamedCompanyConfig[],
    private readonly fetcher: HttpFetcher,
  ) {}

  async fetchJobs(): Promise<ExternalJobListing[]> {
    if (this.companies.length === 0) return [];

    const listings: ExternalJobListing[] = [];
    for (const company of this.companies) {
      const url = `https://boards-api.greenhouse.io/v1/boards/${encodeURIComponent(company.token)}/jobs?content=true`;
      const response = await this.fetcher(url);
      if (!response.ok) {
        throw new Error(
          `Greenhouse request failed for board "${company.token}" with status ${response.status}`,
        );
      }
      const body = (await response.json()) as GreenhouseResponse;
      for (const job of body.jobs ?? []) {
        if (job?.id == null || !job.title || !job.absolute_url) continue;
        listings.push({
          externalId: `${company.token}:${job.id}`,
          employerName: company.displayName,
          title: job.title,
          location: job.location?.name ?? 'Location not specified',
          description: stripHtml(job.content),
          applyUrl: job.absolute_url,
        });
      }
    }
    return listings;
  }
}
