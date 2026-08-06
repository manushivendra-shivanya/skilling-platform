import { ExternalJobListing, JobSourceAdapter } from './job-source-adapter';
import { HttpFetcher } from './http-fetcher';
import { NamedCompanyConfig } from './named-companies.config';
import { stripHtml } from './strip-html';

interface LeverPosting {
  id?: string;
  text?: string;
  categories?: { location?: string };
  descriptionPlain?: string;
  description?: string;
  hostedUrl?: string;
}

/**
 * Lever's public postings API (https://api.lever.co/v0/postings/{company})
 * -- no auth needed, returns a bare array, only for one named company's
 * board at a time. Same empty-by-default company-list and namespaced-id
 * treatment as GreenhouseAdapter -- see that file's comment.
 */
export class LeverAdapter implements JobSourceAdapter {
  readonly key = 'lever';

  constructor(
    private readonly companies: NamedCompanyConfig[],
    private readonly fetcher: HttpFetcher,
  ) {}

  async fetchJobs(): Promise<ExternalJobListing[]> {
    if (this.companies.length === 0) return [];

    const listings: ExternalJobListing[] = [];
    for (const company of this.companies) {
      const url = `https://api.lever.co/v0/postings/${encodeURIComponent(company.token)}?mode=json`;
      const response = await this.fetcher(url);
      if (!response.ok) {
        throw new Error(
          `Lever request failed for company "${company.token}" with status ${response.status}`,
        );
      }
      const postings = (await response.json()) as LeverPosting[];
      for (const posting of postings ?? []) {
        if (!posting?.id || !posting.text || !posting.hostedUrl) continue;
        listings.push({
          externalId: `${company.token}:${posting.id}`,
          employerName: company.displayName,
          title: posting.text,
          location: posting.categories?.location ?? 'Location not specified',
          description:
            posting.descriptionPlain ?? stripHtml(posting.description),
          applyUrl: posting.hostedUrl,
        });
      }
    }
    return listings;
  }
}
