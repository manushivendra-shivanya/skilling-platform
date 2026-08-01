import { Injectable } from '@nestjs/common';
import { deriveEvidenceFreshness, EvidenceWithFreshness } from '../employer/employer-evidence';
import { SupabaseService } from '../supabase/supabase.service';
import { WmsEvidencePayload } from '../workplace-simulation/workplace-simulation.types';

export const CAREER_PASSPORT_DISCLAIMER =
  'Flora provides simulation evidence, not certification.';

export type ShareLinkResolution =
  | { status: 'ok'; evidence: EvidenceWithFreshness[] }
  | { status: 'not_found' | 'revoked' | 'expired' };

export interface AppliedEmployer {
  id: string;
  name: string;
}

interface GrantRow {
  id: string;
  candidate_id: string;
  revoked_at: string | null;
  expires_at: string | null;
}

/**
 * Resolves a candidate-generated public share link (`career_passport_grants`,
 * purpose `public_link`) to the evidence it grants access to, or to the
 * reason it can't be shown. Every resolution attempt is audited -- a
 * denied read must be recorded just as reliably as an allowed one, per
 * ADR-0018 -- mirroring `EmployerService.reviewCandidateEvidence`'s
 * allowed/denied logging, just keyed on the grant rather than an employer.
 */
@Injectable()
export class CareerPassportService {
  constructor(private readonly supabase: SupabaseService) {}

  async resolveShareLink(token: string): Promise<ShareLinkResolution> {
    const { data, error } = await this.supabase.admin
      .from('career_passport_grants')
      .select('id, candidate_id, revoked_at, expires_at')
      .eq('purpose', 'public_link')
      .eq('token', token)
      .maybeSingle();
    if (error) {
      throw new Error(`Failed to look up share link: ${error.message}`);
    }
    const grant = data as GrantRow | null;
    if (!grant) {
      await this.logAccess(null, 'denied', 'NOT_FOUND');
      return { status: 'not_found' };
    }
    if (grant.revoked_at) {
      await this.logAccess(grant.id, 'denied', 'REVOKED');
      return { status: 'revoked' };
    }
    if (grant.expires_at && Date.parse(grant.expires_at) < Date.now()) {
      await this.logAccess(grant.id, 'denied', 'EXPIRED');
      return { status: 'expired' };
    }

    const { data: rows, error: evidenceError } = await this.supabase.admin
      .from('wms_competency_evidence')
      .select('evidence')
      .eq('candidate_id', grant.candidate_id)
      .order('issued_at', { ascending: false });
    if (evidenceError) {
      throw new Error(`Failed to load shared evidence: ${evidenceError.message}`);
    }
    const evidence = (rows ?? []).map(
      (row: { evidence: WmsEvidencePayload }) => row.evidence,
    );

    // Recorded before returning: a disclosure that failed to audit must
    // not be treated as a successful, silent disclosure.
    await this.logAccess(grant.id, 'allowed', null);
    return {
      status: 'ok',
      evidence: deriveEvidenceFreshness(evidence, new Date()),
    };
  }

  /**
   * The candidate's own list of "employers I could grant Career Passport
   * access to" -- every employer behind a non-withdrawn application,
   * deduplicated. A read, not a decision: whether each one currently has
   * an active grant is derived from `career_passport_grants` directly by
   * the app (RLS already scopes that to the candidate's own rows), not
   * returned here, so this stays a single-purpose join the client
   * couldn't otherwise do -- `employers` has no client-facing policy.
   */
  async listAppliedEmployers(candidateId: string): Promise<AppliedEmployer[]> {
    const { data: applications, error } = await this.supabase.admin
      .from('job_applications')
      .select('job_id')
      .eq('candidate_id', candidateId)
      .neq('status', 'withdrawn');
    if (error) {
      throw new Error(`Failed to load applications: ${error.message}`);
    }
    const jobIds = [
      ...new Set((applications ?? []).map((row: { job_id: string }) => row.job_id)),
    ];
    if (jobIds.length === 0) return [];

    const { data: jobs, error: jobsError } = await this.supabase.admin
      .from('jobs')
      .select('employer_id')
      .in('id', jobIds)
      .not('employer_id', 'is', null);
    if (jobsError) {
      throw new Error(`Failed to load applied jobs: ${jobsError.message}`);
    }
    const employerIds = [
      ...new Set(
        (jobs ?? []).map((row: { employer_id: string }) => row.employer_id),
      ),
    ];
    if (employerIds.length === 0) return [];

    const { data: employers, error: employersError } = await this.supabase.admin
      .from('employers')
      .select('id, name')
      .in('id', employerIds)
      .order('name');
    if (employersError) {
      throw new Error(`Failed to load employers: ${employersError.message}`);
    }
    return employers ?? [];
  }

  private async logAccess(
    grantId: string | null,
    outcome: 'allowed' | 'denied',
    denialReason: string | null,
  ): Promise<void> {
    const { error } = await this.supabase.admin
      .from('career_passport_grant_access_log')
      .insert({ grant_id: grantId, outcome, denial_reason: denialReason });
    if (error) {
      throw new Error(
        `Failed to record share-link access audit log: ${error.message}`,
      );
    }
  }
}
