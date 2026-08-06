/**
 * The normalized shape every job source maps its raw response into.
 * Deliberately only the fields JobSyncService needs to build a `jobs`
 * upsert row -- no salary/applyUrl-optional/etc extras that nothing reads.
 * `applyUrl` is always set here (every external source has a real listing
 * URL); Flora-native jobs created via `POST /employer/jobs` never go
 * through an adapter at all, so `jobs.apply_url` stays null for those --
 * see the Phase H migration's column comment.
 *
 * `postedAt` is the source's own original posting date (Adzuna `created`,
 * Jooble `updated`, Careerjet `date`, Greenhouse `first_published`/
 * `updated_at`, Lever `createdAt`) -- all 5 sources were confirmed live to
 * carry a real date field. `JobSyncService` uses this for `jobs.published_at`
 * instead of the sync timestamp, so a job's freshness reflects when it was
 * actually posted, not when Flora happened to sync it.
 */
export interface ExternalJobListing {
  externalId: string;
  employerName: string;
  title: string;
  location: string;
  description: string;
  applyUrl: string;
  /** ISO 8601. Falls back to the sync time if the source's own date is
   * missing or unparseable -- see each adapter's date-mapping helper. */
  postedAt: string;
}

/**
 * One implementation per external job source. `fetchJobs()` must never
 * reject for "not configured" (missing API key, empty named-company list)
 * -- it returns `[]` in that case, so a source without credentials yet is
 * a harmless no-op sync, not a crash. Genuine fetch/parse failures should
 * still throw; JobSyncService is what isolates those per adapter.
 */
export interface JobSourceAdapter {
  readonly key: string;
  fetchJobs(): Promise<ExternalJobListing[]>;
}
