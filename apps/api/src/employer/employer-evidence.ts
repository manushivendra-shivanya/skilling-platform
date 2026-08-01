import { WmsEvidencePayload } from '../workplace-simulation/workplace-simulation.types';

export type EvidenceFreshnessState = 'active' | 'superseded' | 'stale';

export interface EvidenceWithFreshness extends WmsEvidencePayload {
  freshness: EvidenceFreshnessState;
}

const DEFAULT_STALE_AFTER_MS = 180 * 24 * 60 * 60 * 1000;

/**
 * Mirrors the candidate app's `deriveCareerPassportEntries`
 * (career_passport.dart): groups evidence by competency, the newest record
 * per competency is `active` (or `stale` past the staleness window), every
 * older record for that competency is `superseded`. Kept in step
 * deliberately -- an employer and a candidate must never see a different
 * verdict on the same evidence.
 */
export function deriveEvidenceFreshness(
  evidence: WmsEvidencePayload[],
  now: Date,
  staleAfterMs: number = DEFAULT_STALE_AFTER_MS,
): EvidenceWithFreshness[] {
  const byCompetency = new Map<string, WmsEvidencePayload[]>();
  for (const item of evidence) {
    const items = byCompetency.get(item.competencyId) ?? [];
    items.push(item);
    byCompetency.set(item.competencyId, items);
  }

  const result: EvidenceWithFreshness[] = [];
  for (const items of byCompetency.values()) {
    const newestFirst = [...items].sort(
      (a, b) => Date.parse(b.issuedAt) - Date.parse(a.issuedAt),
    );
    newestFirst.forEach((item, index) => {
      const freshness: EvidenceFreshnessState =
        index > 0
          ? 'superseded'
          : now.getTime() - Date.parse(item.issuedAt) > staleAfterMs
            ? 'stale'
            : 'active';
      result.push({ ...item, freshness });
    });
  }

  result.sort((a, b) => Date.parse(b.issuedAt) - Date.parse(a.issuedAt));
  return result;
}
