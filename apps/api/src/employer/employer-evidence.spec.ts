import { deriveEvidenceFreshness } from './employer-evidence';
import { WmsEvidencePayload } from '../workplace-simulation/workplace-simulation.types';

function evidence(
  overrides: Partial<WmsEvidencePayload> & { competencyId: string; issuedAt: string },
): WmsEvidencePayload {
  return {
    id: overrides.id ?? `evidence-${overrides.competencyId}-${overrides.issuedAt}`,
    attemptId: 'attempt-1',
    missionId: 'mission-1',
    missionVersion: '1.0.0',
    scenarioSeed: 1,
    score: 80,
    evidenceType: 'simulation_observation',
    title: 'Observed evidence',
    description: 'Generated from the append-only action trail.',
    verificationStatus: 'systemObserved',
    ...overrides,
  };
}

describe('deriveEvidenceFreshness', () => {
  const now = new Date('2026-08-01T00:00:00Z');

  it('marks the newest record per competency as active', () => {
    const result = deriveEvidenceFreshness(
      [evidence({ competencyId: 'receiving-accuracy', issuedAt: '2026-07-25T00:00:00Z' })],
      now,
    );
    expect(result[0].freshness).toBe('active');
  });

  it('marks older records for the same competency as superseded', () => {
    const older = evidence({
      id: 'older',
      competencyId: 'receiving-accuracy',
      issuedAt: '2026-06-01T00:00:00Z',
    });
    const newer = evidence({
      id: 'newer',
      competencyId: 'receiving-accuracy',
      issuedAt: '2026-07-27T00:00:00Z',
    });

    const result = deriveEvidenceFreshness([older, newer], now);

    expect(result[0].id).toBe('newer');
    expect(result[0].freshness).toBe('active');
    expect(result[1].id).toBe('older');
    expect(result[1].freshness).toBe('superseded');
  });

  it('marks the newest record as stale once past the staleness window', () => {
    const result = deriveEvidenceFreshness(
      [evidence({ competencyId: 'receiving-accuracy', issuedAt: '2026-01-01T00:00:00Z' })],
      now,
      180 * 24 * 60 * 60 * 1000,
    );
    expect(result[0].freshness).toBe('stale');
  });

  it('tracks each competency independently', () => {
    const result = deriveEvidenceFreshness(
      [
        evidence({ id: 'a', competencyId: 'receiving-accuracy', issuedAt: '2026-07-25T00:00:00Z' }),
        evidence({ id: 'b', competencyId: 'put-away-accuracy', issuedAt: '2026-07-25T00:00:00Z' }),
      ],
      now,
    );
    expect(result).toHaveLength(2);
    expect(result.every((item) => item.freshness === 'active')).toBe(true);
  });
});
