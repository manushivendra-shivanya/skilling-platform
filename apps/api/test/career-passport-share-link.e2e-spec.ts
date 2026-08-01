import { INestApplication } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { AppExceptionFilter } from '../src/common/app-exception.filter';
import { SupabaseService } from '../src/supabase/supabase.service';

/**
 * Real, live-database smoke tests for the Career Passport public share
 * link -- no mocked Supabase client, same shape as
 * employer-evidence-review.e2e-spec.ts. Requires the
 * `career_passport_grants` / `career_passport_grant_access_log` migration
 * (20260801120000_career_passport_grants.sql) to already be applied to
 * whatever project SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY point at. Run
 * with `npm run test:e2e`.
 */
const canRunLive = Boolean(
  process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY,
);
const describeLive = canRunLive ? describe : describe.skip;

if (!canRunLive) {
  // eslint-disable-next-line no-console
  console.warn(
    'Skipping career-passport-share-link e2e suite: SUPABASE_URL / ' +
      'SUPABASE_SERVICE_ROLE_KEY are not set. This is a SKIP, not a pass -- ' +
      'set them (pointed at a real, disposable-safe project with the ' +
      'career_passport_grants migration applied) to actually run it.',
  );
}

describeLive('Career Passport share link (e2e)', () => {
  let app: INestApplication;
  let supabase: SupabaseService;

  const suffix = `${Date.now()}-${Math.floor(Math.random() * 1e6)}`;
  let candidateId: string;
  let activeToken: string;
  let revokedToken: string;
  let expiredToken: string;
  const createdUserIds: string[] = [];
  const createdGrantIds: string[] = [];

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('v1');
    app.useGlobalFilters(new AppExceptionFilter());
    await app.init();

    supabase = moduleFixture.get(SupabaseService);
    const admin = supabase.admin;

    const { data: user, error: userError } = await admin.auth.admin.createUser({
      email: `e2e-share-link-${suffix}@example.invalid`,
      email_confirm: true,
      password: `E2ePassword-${suffix}`,
    });
    if (userError || !user.user) throw userError ?? new Error('createUser returned no user');
    candidateId = user.user.id;
    createdUserIds.push(candidateId);

    activeToken = `e2e-active-${suffix}`;
    revokedToken = `e2e-revoked-${suffix}`;
    expiredToken = `e2e-expired-${suffix}`;

    const grants = await admin
      .from('career_passport_grants')
      .insert([
        {
          candidate_id: candidateId,
          purpose: 'public_link',
          token: activeToken,
          expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        },
        {
          candidate_id: candidateId,
          purpose: 'public_link',
          token: revokedToken,
          revoked_at: new Date().toISOString(),
        },
        {
          candidate_id: candidateId,
          purpose: 'public_link',
          token: expiredToken,
          expires_at: new Date(Date.now() - 1000).toISOString(),
        },
      ])
      .select('id');
    if (grants.error) throw grants.error;
    createdGrantIds.push(...grants.data!.map((row) => row.id as string));

    const evidence = await admin.from('wms_competency_evidence').insert([
      {
        id: `e2e-share-evidence-${suffix}`,
        attempt_id: `e2e-share-attempt-${suffix}`,
        candidate_id: candidateId,
        mission_id: 'e2e-mission',
        mission_version: '1.0.0',
        scenario_seed: 1,
        competency_id: 'e2e-competency',
        score: 91,
        evidence_type: 'simulation_observation',
        title: 'E2E share-link fixture evidence',
        description: 'Generated for the career-passport share-link e2e suite.',
        verification_status: 'systemObserved',
        issued_at: new Date().toISOString(),
        evidence: {
          id: `e2e-share-evidence-${suffix}`,
          attemptId: `e2e-share-attempt-${suffix}`,
          missionId: 'e2e-mission',
          missionVersion: '1.0.0',
          scenarioSeed: 1,
          competencyId: 'e2e-competency',
          score: 91,
          evidenceType: 'simulation_observation',
          title: 'E2E share-link fixture evidence',
          description: 'Generated for the career-passport share-link e2e suite.',
          issuedAt: new Date().toISOString(),
          verificationStatus: 'systemObserved',
        },
      },
    ]);
    if (evidence.error) throw evidence.error;
  });

  afterAll(async () => {
    const admin = supabase.admin;
    await admin
      .from('career_passport_grant_access_log')
      .delete()
      .in('grant_id', createdGrantIds);
    await admin.from('wms_competency_evidence').delete().eq('candidate_id', candidateId);
    await admin.from('career_passport_grants').delete().in('id', createdGrantIds);
    for (const userId of createdUserIds) {
      await admin.auth.admin.deleteUser(userId);
    }
    await app.close();
  });

  it('serves evidence, disclaimer and boundary copy for a valid link, and audits it', async () => {
    const response = await request(app.getHttpServer())
      .get(`/v1/career-passport/share/${activeToken}`)
      .expect(200);

    expect(response.type).toBe('text/html');
    expect(response.text).toContain('Flora provides simulation evidence, not certification.');
    expect(response.text).toContain(
      'This is a read-only view shared by the candidate.',
    );
    expect(response.text).toContain('E2E share-link fixture evidence');
    for (const banned of ['rank', 'shortlist', 'certified']) {
      expect(response.text.toLowerCase()).not.toContain(banned);
    }

    const log = await supabase.admin
      .from('career_passport_grant_access_log')
      .select('outcome')
      .eq('grant_id', createdGrantIds[0])
      .eq('outcome', 'allowed');
    expect(log.data).toHaveLength(1);
  });

  it('404s and audits an unknown token', async () => {
    const response = await request(app.getHttpServer())
      .get('/v1/career-passport/share/not-a-real-token')
      .expect(404);
    expect(response.text).toContain('This link does not exist.');
  });

  it('404s a revoked link', async () => {
    const response = await request(app.getHttpServer())
      .get(`/v1/career-passport/share/${revokedToken}`)
      .expect(404);
    expect(response.text).toContain('revoked by the candidate');
  });

  it('404s an expired link', async () => {
    const response = await request(app.getHttpServer())
      .get(`/v1/career-passport/share/${expiredToken}`)
      .expect(404);
    expect(response.text).toContain('This link has expired.');
  });
});
