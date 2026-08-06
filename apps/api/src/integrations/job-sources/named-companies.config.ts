/**
 * Greenhouse and Lever's public job-board APIs need no API key, but only
 * return jobs for a specific named company's board -- there is no
 * "search across every company on this ATS" endpoint. Both lists are
 * empty by default; the corresponding adapter treats an empty list as
 * "not configured yet" and returns `[]` rather than erroring. Add real
 * entries here (and redeploy) once specific target employers' board
 * tokens are known -- see docs/25-job-sourcing-voice-ai-career-progression-plan.md.
 */
export interface NamedCompanyConfig {
  displayName: string;
  /** Greenhouse board token or Lever company slug used in the public API URL. */
  token: string;
}

export const GREENHOUSE_BOARD_COMPANIES: NamedCompanyConfig[] = [];

export const LEVER_COMPANIES: NamedCompanyConfig[] = [];
