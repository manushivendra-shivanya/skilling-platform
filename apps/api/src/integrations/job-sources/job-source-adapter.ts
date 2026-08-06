/**
 * The normalized shape every job source maps its raw response into.
 * Deliberately only the fields JobSyncService needs to build a `jobs`
 * upsert row -- no salary/applyUrl-optional/etc extras that nothing reads.
 * `applyUrl` is always set here (every external source has a real listing
 * URL); Flora-native jobs created via `POST /employer/jobs` never go
 * through an adapter at all, so `jobs.apply_url` stays null for those --
 * see the Phase H migration's column comment.
 */
export interface ExternalJobListing {
  externalId: string;
  employerName: string;
  title: string;
  location: string;
  description: string;
  applyUrl: string;
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
