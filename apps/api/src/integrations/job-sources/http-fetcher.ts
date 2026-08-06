/**
 * Thin abstraction over the outbound HTTP call every adapter makes, so
 * adapters take it as a plain constructor argument (like `SupabaseService`
 * elsewhere) and tests substitute a fake instead of mocking global `fetch`.
 * The real implementation (wired in job-sources.module.ts) is just Node's
 * built-in global `fetch` -- no new HTTP dependency needed.
 */
export type HttpFetcher = (
  input: string,
  init?: RequestInit,
) => Promise<Response>;

export const HTTP_FETCHER = Symbol('HTTP_FETCHER');
