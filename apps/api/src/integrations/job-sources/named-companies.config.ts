/**
 * Greenhouse and Lever's public job-board APIs need no API key, but only
 * return jobs for a specific named company's board -- there is no
 * "search across every company on this ATS" endpoint. Both lists are
 * empty by default; the corresponding adapter treats an empty list as
 * "not configured yet" and returns `[]` rather than erroring. Add real
 * entries here (and redeploy) once specific target employers' board
 * tokens are known -- see docs/25-job-sourcing-voice-ai-career-progression-plan.md.
 *
 * The entries below were verified live (curl against the real Greenhouse/
 * Lever endpoints, spot-checking job counts and titles) rather than
 * guessed. The genuinely relevant Indian warehouse/logistics/D2C
 * employers for this app's mission (Delhivery, Porter, Tata 1mg,
 * BigBasket) all run on Darwinbox, which has no public API like
 * Greenhouse/Lever -- so this channel structurally skews toward fintech/
 * SaaS boards with thin operational-role coverage. Meesho is the one
 * standout: genuine warehouse/sort-center/last-mile postings. The rest
 * are kept in because they're free/harmless (an empty result for a given
 * company is a normal no-op, not an error) -- remove any entry that
 * turns out not to be worth the extra sync-run noise.
 */
export interface NamedCompanyConfig {
  displayName: string;
  /** Greenhouse board token or Lever company slug used in the public API URL. */
  token: string;
}

export const GREENHOUSE_BOARD_COMPANIES: NamedCompanyConfig[] = [
  // 74 jobs. Fintech/payments -- mostly corporate/tech; only a
  // "Lending Operations" / "Delivery Engineer" (tech delivery, not
  // logistics) matched operational keywords in verification.
  { displayName: 'PhonePe', token: 'phonepe' },
  // 8 jobs, all content/finance/design -- zero operational relevance.
  { displayName: 'Groww', token: 'groww' },
  // 24 jobs, 1 "Business Operations" analyst (corporate ops, not
  // warehouse). Real token found via WebSearch, not the more obvious
  // "razorpay" guess (that 404s -- wrong token entirely).
  { displayName: 'Razorpay', token: 'razorpaysoftwareprivatelimited' },
];

export const LEVER_COMPANIES: NamedCompanyConfig[] = [
  // 48 jobs. BEST HIT for this mission -- genuine warehouse/logistics
  // roles: "Automation Engineer (Warehouse Automation)", "Sort Center
  // Design & Operations", "Cluster Head Middle Mile", "Program Ops
  // (Fulfilment & Experience)", "Senior Manager - Last Mile".
  { displayName: 'Meesho', token: 'meesho' },
  // Only 4 open postings, none operational -- fintech. Kept for
  // coverage; low expected yield.
  { displayName: 'CRED', token: 'cred' },
  // 242 jobs but ops hits are corporate ("Campaign Operations", "SOC
  // Security Operations"), not warehouse/fulfillment. One genuine
  // "Supply Chain, Logistics and Operations Executive" role exists but
  // is based in Jakarta, Indonesia, not India.
  { displayName: 'Paytm', token: 'paytm' },
];
