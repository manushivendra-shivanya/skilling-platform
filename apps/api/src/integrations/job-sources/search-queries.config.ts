/**
 * Query terms run against Adzuna, Jooble, and Careerjet -- one API call
 * per term, per sync. Kept deliberately small rather than maximal: Jooble's
 * free-tier key is capped at 500 total requests (per their own onboarding
 * email), and a 6-hourly cron × a long query list would burn that in days.
 * Mixes a few broad keyword-group phrases with a handful of named
 * high-priority logistics/fulfillment employers confirmed (via live
 * testing) to have real listings indexed on these aggregators even though
 * they don't use Greenhouse/Lever -- e.g. Delhivery's genuine ops roles
 * ("Director - Hub Operations", "Vendor Coordinator") only surfaced under
 * a company-name search, not the generic "warehouse logistics" phrase,
 * since Adzuna ranks by relevance to the literal query and only the first
 * page was being fetched.
 *
 * Extend this list once a higher request quota is available -- it's a
 * plain array specifically so that's a one-line change, not a code change.
 */
export const SEARCH_QUERIES: string[] = [
  // Broad keyword groups, chosen to catch different phrasing across
  // sources without duplicating near-identical single-word terms.
  'warehouse logistics',
  'dispatch fulfillment',
  'last mile delivery',
  'hub operations supply chain',
  // Named high-priority employers -- confirmed live to have real
  // operational-role listings indexed on at least one aggregator despite
  // using an ATS (Darwinbox) with no public job-board API of its own.
  'Delhivery',
  'Meesho',
  'Ecom Express',
  'XpressBees',
];
