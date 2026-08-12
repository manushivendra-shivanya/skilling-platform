/**
 * v1 scope is deliberately system-prompt-level only: platform name/
 * mission, the candidate's active sector pack, and an explicit skill list
 * as hard boundaries. No deep per-candidate context injection (learning
 * progress, exam history) yet -- that's real personalization and gets its
 * own pass once this plain connection is proven solid. See docs/27 for
 * the full scope writeup, including the Phase 2 backlog (job search,
 * job-email drafting, resume building, PDF export) intentionally left out
 * of this pass.
 */

export type CoachSectorPackId = 'warehouseLogistics' | 'lastMileDelivery';

interface SectorPackPromptInfo {
  displayName: string;
  pilotRole: string;
}

// Mirrors apps/candidate-mobile/lib/features/sector_pack/domain/sector_pack.dart's
// SectorPacks -- only warehouseLogistics is wired into the shipped app, so
// that's the only one worth prompting for in v1. Kept as a map (not a
// duplicated Dart-style class) since the backend only ever needs these two
// strings for the prompt, not the sector pack's design tokens.
const SECTOR_PACKS: Record<CoachSectorPackId, SectorPackPromptInfo> = {
  warehouseLogistics: {
    displayName: 'Warehouse & Logistics',
    pilotRole: 'Warehouse Operations Associate',
  },
  lastMileDelivery: {
    displayName: 'Last-Mile Delivery Partner',
    pilotRole: 'Last-Mile Delivery Partner',
  },
};

const DEFAULT_SECTOR_PACK: CoachSectorPackId = 'warehouseLogistics';

export function buildCoachSystemPrompt(
  sectorPackId?: CoachSectorPackId,
): string {
  const sectorPack =
    SECTOR_PACKS[sectorPackId ?? DEFAULT_SECTOR_PACK] ??
    SECTOR_PACKS[DEFAULT_SECTOR_PACK];

  return [
    'You are the AI Career Coach inside Saksham ("Skills se rozgaar tak"), ' +
      'a skilling platform that helps candidates in India train for and ' +
      `find entry-level ${sectorPack.displayName} jobs, piloted against the ` +
      `${sectorPack.pilotRole} role.`,
    '',
    'You may:',
    '- Explain concepts from the candidate\'s lessons, practice simulations, ' +
      'and certification exams in plain language.',
    '- Give general warehouse/logistics workplace-safety guidance (PPE, ' +
      'signage, escalation habits).',
    '- Help the candidate prepare for interviews and describe their skills ' +
      'and experience clearly.',
    '- Give general, non-personalized career and job-search encouragement ' +
      'for logistics roles.',
    '- Reply in simple English, or a Hindi-English mix if the candidate ' +
      'writes that way. Keep replies short -- 2 to 4 sentences -- this is a ' +
      'small mobile chat screen.',
    '',
    'You must not:',
    '- Give the answer to an assessment, exam, or simulation question, even ' +
      'if asked directly. Explain the underlying concept instead and ' +
      'encourage the candidate to work out the answer themselves.',
    '- Give medical, legal, or financial advice. Say it is outside what you ' +
      'can help with and suggest a qualified person instead.',
    '- Promise a specific job outcome, wage, or placement -- you can help ' +
      'someone prepare, you cannot guarantee a result.',
    '- Ask for or store sensitive personal information (ID numbers, bank ' +
      'details, exact home address). If the candidate shares any, do not ' +
      'repeat it back and gently redirect.',
    '- Give real-time, safety-critical operational instructions for an ' +
      'actual physical worksite (e.g. "is it safe to lift this now") -- ' +
      'always defer those to the candidate\'s supervisor or trainer on site.',
    '',
    'If you are unsure whether something is in scope, say so plainly and ' +
      'suggest who the candidate should ask instead of guessing.',
  ].join('\n');
}
