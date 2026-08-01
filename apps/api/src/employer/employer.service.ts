import { Injectable } from '@nestjs/common';
import { AppError } from '../common/app-error';
import { SupabaseService } from '../supabase/supabase.service';
import { WmsEvidencePayload } from '../workplace-simulation/workplace-simulation.types';
import { deriveEvidenceFreshness, EvidenceWithFreshness } from './employer-evidence';

const EMPLOYER_SHARING_PURPOSE = 'employer_sharing';
const EMPLOYER_REVIEW_GRANT_PURPOSE = 'employer_review';

export const CAREER_PASSPORT_DISCLAIMER =
  'Flora provides simulation evidence, not certification.';
export const EMPLOYER_DECISION_BOUNDARY =
  'Employer reviews evidence and decides.';

export interface EmployerApplicant {
  candidateId: string;
  jobId: string;
  jobTitle: string;
  applicationStatus: string;
  appliedAt: string;
}

export interface EmployerEvidenceView {
  disclaimer: string;
  decisionBoundary: string;
  candidateId: string;
  evidence: EvidenceWithFreshness[];
}

/**
 * Enforces the access rule for Employer Evidence Review: an employer may
 * only see a candidate's evidence if that candidate applied (and has not
 * withdrawn) to one of this employer's jobs, AND both `employer_sharing`
 * consent (the general, application-time consent to be visible to
 * employers at all) and an active, employer-specific
 * `career_passport_grants` row (`purpose = 'employer_review'`, scoped to
 * this exact employer) are currently active. The single global
 * `career_passport_sharing` toggle this replaced granted every applied-to
 * employer the same access at once; a per-employer grant lets the
 * candidate decide employer by employer. There is no browsing, no global
 * "shareable" pool, and no ranking -- every read is scoped to a specific
 * application and audited.
 */
@Injectable()
export class EmployerService {
  constructor(private readonly supabase: SupabaseService) {}

  async listApplicants(employerId: string): Promise<EmployerApplicant[]> {
    const jobsById = await this.employerJobTitles(employerId);
    if (jobsById.size === 0) return [];

    const { data: applications, error } = await this.supabase.admin
      .from('job_applications')
      .select('candidate_id, job_id, status, created_at')
      .in('job_id', [...jobsById.keys()])
      .neq('status', 'withdrawn');
    if (error) {
      throw new Error(`Failed to load applicants: ${error.message}`);
    }

    return (applications ?? []).map(
      (row: {
        candidate_id: string;
        job_id: string;
        status: string;
        created_at: string;
      }) => ({
        candidateId: row.candidate_id,
        jobId: row.job_id,
        jobTitle: jobsById.get(row.job_id) ?? '',
        applicationStatus: row.status,
        appliedAt: row.created_at,
      }),
    );
  }

  async reviewCandidateEvidence(
    employerId: string,
    candidateId: string,
  ): Promise<EmployerEvidenceView> {
    const application = await this.findAccessibleApplication(
      employerId,
      candidateId,
    );
    if (!application) {
      await this.logAccess(
        employerId,
        candidateId,
        null,
        'denied',
        'NO_ACTIVE_APPLICATION',
      );
      throw AppError.forbidden(
        'EMPLOYER_ACCESS_DENIED',
        'This candidate has not applied to one of your jobs.',
      );
    }

    const shared =
      (await this.hasActiveConsent(candidateId, EMPLOYER_SHARING_PURPOSE)) &&
      (await this.hasActiveEmployerGrant(employerId, candidateId));
    if (!shared) {
      await this.logAccess(
        employerId,
        candidateId,
        application.jobId,
        'denied',
        'SHARING_NOT_ACTIVE',
      );
      throw AppError.forbidden(
        'EMPLOYER_ACCESS_DENIED',
        'This candidate has not shared their Career Passport.',
      );
    }

    const { data: rows, error } = await this.supabase.admin
      .from('wms_competency_evidence')
      .select('evidence')
      .eq('candidate_id', candidateId)
      .order('issued_at', { ascending: false });
    if (error) {
      throw new Error(`Failed to load candidate evidence: ${error.message}`);
    }
    const evidence = (rows ?? []).map(
      (row: { evidence: WmsEvidencePayload }) => row.evidence,
    );

    // Recorded before returning: a disclosure that failed to audit must not
    // be treated as a successful, silent disclosure.
    await this.logAccess(employerId, candidateId, application.jobId, 'allowed', null);

    return {
      disclaimer: CAREER_PASSPORT_DISCLAIMER,
      decisionBoundary: EMPLOYER_DECISION_BOUNDARY,
      candidateId,
      evidence: deriveEvidenceFreshness(evidence, new Date()),
    };
  }

  private async employerJobTitles(
    employerId: string,
  ): Promise<Map<string, string>> {
    const { data, error } = await this.supabase.admin
      .from('jobs')
      .select('id, title')
      .eq('employer_id', employerId);
    if (error) {
      throw new Error(`Failed to load employer jobs: ${error.message}`);
    }
    return new Map(
      (data ?? []).map((job: { id: string; title: string }) => [
        job.id,
        job.title,
      ]),
    );
  }

  private async findAccessibleApplication(
    employerId: string,
    candidateId: string,
  ): Promise<{ jobId: string } | null> {
    const jobsById = await this.employerJobTitles(employerId);
    if (jobsById.size === 0) return null;

    const { data, error } = await this.supabase.admin
      .from('job_applications')
      .select('job_id')
      .eq('candidate_id', candidateId)
      .in('job_id', [...jobsById.keys()])
      .neq('status', 'withdrawn')
      .limit(1)
      .maybeSingle();
    if (error) {
      throw new Error(`Failed to check application: ${error.message}`);
    }
    return data ? { jobId: data.job_id } : null;
  }

  private async hasActiveEmployerGrant(
    employerId: string,
    candidateId: string,
  ): Promise<boolean> {
    const { data, error } = await this.supabase.admin
      .from('career_passport_grants')
      .select('id, expires_at')
      .eq('candidate_id', candidateId)
      .eq('employer_id', employerId)
      .eq('purpose', EMPLOYER_REVIEW_GRANT_PURPOSE)
      .is('revoked_at', null)
      .maybeSingle();
    if (error) {
      throw new Error(`Failed to check employer grant: ${error.message}`);
    }
    if (!data) return false;
    const expiresAt = data.expires_at as string | null;
    return !expiresAt || Date.parse(expiresAt) >= Date.now();
  }

  private async hasActiveConsent(
    candidateId: string,
    purpose: string,
  ): Promise<boolean> {
    const { data, error } = await this.supabase.admin
      .from('consent_grants')
      .select('id')
      .eq('candidate_id', candidateId)
      .eq('purpose', purpose)
      .is('revoked_at', null)
      .limit(1)
      .maybeSingle();
    if (error) {
      throw new Error(`Failed to check consent: ${error.message}`);
    }
    return data != null;
  }

  private async logAccess(
    employerId: string,
    candidateId: string,
    jobId: string | null,
    outcome: 'allowed' | 'denied',
    denialReason: string | null,
  ): Promise<void> {
    const { error } = await this.supabase.admin
      .from('employer_evidence_access_log')
      .insert({
        employer_id: employerId,
        candidate_id: candidateId,
        job_id: jobId,
        outcome,
        denial_reason: denialReason,
      });
    if (error) {
      throw new Error(`Failed to record evidence access audit log: ${error.message}`);
    }
  }
}
