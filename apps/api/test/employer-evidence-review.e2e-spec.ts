import { INestApplication } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { AppExceptionFilter } from '../src/common/app-exception.filter';
import { hashApiKey } from '../src/employer/api-key-hash';
import { SupabaseService } from '../src/supabase/supabase.service';

/**
 * Real, live-database smoke tests for the Employer Evidence Review MVP --
 * no mocked Supabase client. They create and tear down their own throwaway
 * employers, jobs, a candidate and consent/evidence rows against whatever
 * project SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY point at (JobSkills in
 * practice), so they only run when those are actually configured. Run with
 * `npm run test:e2e`.
 */
const canRunLive = Boolean(
  process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY,
);
const describeLive = canRunLive ? describe : describe.skip;

if (!canRunLive) {
  // eslint-disable-next-line no-console
  console.warn(
    'Skipping employer-evidence-review e2e suite: SUPABASE_URL / ' +
      'SUPABASE_SERVICE_ROLE_KEY are not set. This is a SKIP, not a pass -- ' +
      'set them (pointed at a real, disposable-safe project) to actually run it.',
  );
}

describeLive('Employer Evidence Review MVP (e2e)', () => {
  let app: INestApplication;
  let supabase: SupabaseService;

  const suffix = `${Date.now()}-${Math.floor(Math.random() * 1e6)}`;
  const employerAKey = `e2e-employer-a-key-${suffix}`;
  const employerBKey = `e2e-employer-b-key-${suffix}`;

  let employerAId: string;
  let employerBId: string;
  let jobAId: string;
  let jobBId: string;
  // Applied to job A, both consents active -- the happy path.
  let sharedCandidateId: string;
  // Applied to job A, no consent grants at all -- consent-denied path.
  let unsharedCandidateId: string;
  // No application to any of employer A's jobs -- no-application-denied path.
  let strangerCandidateId: string;

  const createdUserIds: string[] = [];

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

    const employerRows = await admin
      .from('employers')
      .insert([
        { name: `E2E Employer A ${suffix}`, api_key_hash: hashApiKey(employerAKey) },
        { name: `E2E Employer B ${suffix}`, api_key_hash: hashApiKey(employerBKey) },
      ])
      .select('id, name');
    if (employerRows.error) throw employerRows.error;
    employerAId = employerRows.data!.find((r) => r.name.includes('Employer A'))!.id;
    employerBId = employerRows.data!.find((r) => r.name.includes('Employer B'))!.id;

    const jobRows = await admin
      .from('jobs')
      .insert([
        {
          employer_id: employerAId,
          employer_name: `E2E Employer A ${suffix}`,
          title: 'E2E Warehouse Associate',
          location: 'Test City',
          description: 'E2E fixture job for employer A.',
        },
        {
          employer_id: employerBId,
          employer_name: `E2E Employer B ${suffix}`,
          title: 'E2E Inventory Executive',
          location: 'Test City',
          description: 'E2E fixture job for employer B.',
        },
      ])
      .select('id, employer_id');
    if (jobRows.error) throw jobRows.error;
    jobAId = jobRows.data!.find((r) => r.employer_id === employerAId)!.id;
    jobBId = jobRows.data!.find((r) => r.employer_id === employerBId)!.id;

    async function createCandidate(label: string): Promise<string> {
      const { data, error } = await admin.auth.admin.createUser({
        email: `e2e-${label}-${suffix}@example.invalid`,
        email_confirm: true,
        password: `E2ePassword-${suffix}`,
      });
      if (error || !data.user) throw error ?? new Error('createUser returned no user');
      createdUserIds.push(data.user.id);
      return data.user.id;
    }

    sharedCandidateId = await createCandidate('shared');
    unsharedCandidateId = await createCandidate('unshared');
    strangerCandidateId = await createCandidate('stranger');

    const applications = await admin.from('job_applications').insert([
      {
        job_id: jobAId,
        candidate_id: sharedCandidateId,
        idempotency_key: `e2e-${suffix}-shared`,
      },
      {
        job_id: jobAId,
        candidate_id: unsharedCandidateId,
        idempotency_key: `e2e-${suffix}-unshared`,
      },
    ]);
    if (applications.error) throw applications.error;

    const grantedAt = new Date().toISOString();
    const consents = await admin.from('consent_grants').insert([
      {
        candidate_id: sharedCandidateId,
        purpose: 'employer_sharing',
        policy_version: 'e2e-1',
        granted_at: grantedAt,
      },
      {
        candidate_id: sharedCandidateId,
        purpose: 'career_passport_sharing',
        policy_version: 'e2e-1',
        granted_at: grantedAt,
      },
    ]);
    if (consents.error) throw consents.error;

    const evidence = await admin.from('wms_competency_evidence').insert([
      {
        id: `e2e-evidence-${suffix}`,
        attempt_id: `e2e-attempt-${suffix}`,
        candidate_id: sharedCandidateId,
        mission_id: 'e2e-mission',
        mission_version: '1.0.0',
        scenario_seed: 1,
        competency_id: 'e2e-competency',
        score: 88,
        evidence_type: 'simulation_observation',
        title: 'E2E fixture evidence',
        description: 'Generated for the employer evidence review e2e suite.',
        verification_status: 'systemObserved',
        issued_at: new Date().toISOString(),
        evidence: {
          id: `e2e-evidence-${suffix}`,
          attemptId: `e2e-attempt-${suffix}`,
          missionId: 'e2e-mission',
          missionVersion: '1.0.0',
          scenarioSeed: 1,
          competencyId: 'e2e-competency',
          score: 88,
          evidenceType: 'simulation_observation',
          title: 'E2E fixture evidence',
          description: 'Generated for the employer evidence review e2e suite.',
          issuedAt: new Date().toISOString(),
          verificationStatus: 'systemObserved',
        },
      },
    ]);
    if (evidence.error) throw evidence.error;
  });

  afterAll(async () => {
    const admin = supabase.admin;
    await admin.from('employer_evidence_access_log').delete().in('employer_id', [
      employerAId,
      employerBId,
    ]);
    await admin.from('wms_competency_evidence').delete().eq('candidate_id', sharedCandidateId);
    await admin
      .from('job_applications')
      .delete()
      .in('candidate_id', [sharedCandidateId, unsharedCandidateId, strangerCandidateId]);
    await admin
      .from('consent_grants')
      .delete()
      .in('candidate_id', [sharedCandidateId, unsharedCandidateId, strangerCandidateId]);
    await admin.from('jobs').delete().in('id', [jobAId, jobBId]);
    await admin.from('employers').delete().in('id', [employerAId, employerBId]);
    for (const userId of createdUserIds) {
      await admin.auth.admin.deleteUser(userId);
    }
    await app.close();
  });

  it('rejects a request with no API key', async () => {
    await request(app.getHttpServer()).get('/v1/employer/applicants').expect(401);
  });

  it('rejects an invalid API key', async () => {
    await request(app.getHttpServer())
      .get('/v1/employer/applicants')
      .set('Authorization', 'Bearer not-a-real-key')
      .expect(401);
  });

  it('lists only this employer\'s own applicants', async () => {
    const response = await request(app.getHttpServer())
      .get('/v1/employer/applicants')
      .set('Authorization', `Bearer ${employerAKey}`)
      .expect(200);

    const candidateIds = response.body.applicants.map(
      (applicant: { candidateId: string }) => applicant.candidateId,
    );
    expect(candidateIds).toEqual(
      expect.arrayContaining([sharedCandidateId, unsharedCandidateId]),
    );
    expect(candidateIds).not.toContain(strangerCandidateId);
    expect(
      response.body.applicants.every((a: { jobId: string }) => a.jobId === jobAId),
    ).toBe(true);
  });

  it(
    'returns disclaimer, decision boundary and freshness-labelled evidence, ' +
      'with no ranking or shortlist fields, when the candidate applied and both ' +
      'consents are active',
    async () => {
      const response = await request(app.getHttpServer())
        .get(`/v1/employer/applicants/${sharedCandidateId}/evidence`)
        .set('Authorization', `Bearer ${employerAKey}`)
        .expect(200);

      expect(response.body.disclaimer).toBe(
        'Flora provides simulation evidence, not certification.',
      );
      expect(response.body.decisionBoundary).toBe(
        'Employer reviews evidence and decides.',
      );
      expect(response.body.evidence).toHaveLength(1);
      expect(response.body.evidence[0]).toMatchObject({
        id: `e2e-evidence-${suffix}`,
        freshness: 'active',
      });

      const serialised = JSON.stringify(response.body);
      for (const banned of ['rank', 'ranking', 'shortlist', 'certified']) {
        expect(serialised.toLowerCase()).not.toContain(banned);
      }

      const log = await supabase.admin
        .from('employer_evidence_access_log')
        .select('outcome, employer_id, candidate_id, job_id')
        .eq('employer_id', employerAId)
        .eq('candidate_id', sharedCandidateId)
        .eq('outcome', 'allowed');
      expect(log.data).toHaveLength(1);
      expect(log.data![0].job_id).toBe(jobAId);
    },
  );

  it('denies and audits access to a candidate who never applied', async () => {
    await request(app.getHttpServer())
      .get(`/v1/employer/applicants/${strangerCandidateId}/evidence`)
      .set('Authorization', `Bearer ${employerAKey}`)
      .expect(403)
      .expect((res) => {
        expect(res.body.error.code).toBe('EMPLOYER_ACCESS_DENIED');
      });

    const log = await supabase.admin
      .from('employer_evidence_access_log')
      .select('outcome, denial_reason')
      .eq('employer_id', employerAId)
      .eq('candidate_id', strangerCandidateId)
      .eq('outcome', 'denied');
    expect(log.data).toHaveLength(1);
    expect(log.data![0].denial_reason).toBe('NO_ACTIVE_APPLICATION');
  });

  it('denies and audits access when sharing consent is not active', async () => {
    await request(app.getHttpServer())
      .get(`/v1/employer/applicants/${unsharedCandidateId}/evidence`)
      .set('Authorization', `Bearer ${employerAKey}`)
      .expect(403)
      .expect((res) => {
        expect(res.body.error.code).toBe('EMPLOYER_ACCESS_DENIED');
      });

    const log = await supabase.admin
      .from('employer_evidence_access_log')
      .select('outcome, denial_reason')
      .eq('employer_id', employerAId)
      .eq('candidate_id', unsharedCandidateId)
      .eq('outcome', 'denied');
    expect(log.data).toHaveLength(1);
    expect(log.data![0].denial_reason).toBe('SHARING_NOT_ACTIVE');
  });

  it('never lets employer B see employer A\'s applicant', async () => {
    await request(app.getHttpServer())
      .get(`/v1/employer/applicants/${sharedCandidateId}/evidence`)
      .set('Authorization', `Bearer ${employerBKey}`)
      .expect(403);
  });
});
