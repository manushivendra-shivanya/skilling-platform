import { Injectable } from '@nestjs/common';
import { AppError } from '../common/app-error';
import { SupabaseService } from '../supabase/supabase.service';

export interface Job {
  id: string;
  employer_name: string;
  title: string;
  location: string;
  description: string;
  source: string;
  apply_url: string | null;
  published_at: string | null;
}

export interface JobApplication {
  id: string;
  job_id: string;
  candidate_id: string;
  status: string;
  created_at: string;
}

const EMPLOYER_SHARING_CONSENT_PURPOSE = 'employer_sharing';

@Injectable()
export class JobsService {
  constructor(private readonly supabase: SupabaseService) {}

  async listPublishedJobs(): Promise<Job[]> {
    const { data, error } = await this.supabase.admin
      .from('jobs')
      .select(
        'id, employer_name, title, location, description, source, apply_url, published_at',
      )
      .eq('status', 'published')
      .order('published_at', { ascending: false });
    if (error) {
      throw new Error(`Failed to load jobs: ${error.message}`);
    }
    return data ?? [];
  }

  async listApplicationsForCandidate(candidateId: string): Promise<string[]> {
    const { data, error } = await this.supabase.admin
      .from('job_applications')
      .select('job_id')
      .eq('candidate_id', candidateId);
    if (error) {
      throw new Error(`Failed to load applications: ${error.message}`);
    }
    return (data ?? []).map((row: { job_id: string }) => row.job_id);
  }

  /**
   * Idempotent: a repeated call for the same candidate and job (whatever
   * Idempotency-Key is sent) returns the existing application rather than
   * erroring or creating a duplicate. The unique (job_id, candidate_id)
   * constraint in the migration is what makes that safe under concurrent
   * requests, not just this read-then-write check.
   */
  async applyToJob(
    candidateId: string,
    jobId: string,
    idempotencyKey: string,
  ): Promise<{ application: JobApplication; created: boolean }> {
    const { data: job, error: jobError } = await this.supabase.admin
      .from('jobs')
      .select('id')
      .eq('id', jobId)
      .eq('status', 'published')
      .maybeSingle();
    if (jobError) {
      throw new Error(`Failed to load job: ${jobError.message}`);
    }
    if (!job) {
      throw AppError.notFound('JOB_NOT_FOUND', 'This job is not available.');
    }

    const hasConsent = await this.hasActiveEmployerSharingConsent(candidateId);
    if (!hasConsent) {
      throw AppError.consentRequired(
        'Grant employer-sharing consent before applying to a job.',
      );
    }

    const { data: existing, error: existingError } = await this.supabase.admin
      .from('job_applications')
      .select('id, job_id, candidate_id, status, created_at')
      .eq('job_id', jobId)
      .eq('candidate_id', candidateId)
      .maybeSingle();
    if (existingError) {
      throw new Error(
        `Failed to check existing application: ${existingError.message}`,
      );
    }
    if (existing) {
      return { application: existing, created: false };
    }

    const { data: created, error: insertError } = await this.supabase.admin
      .from('job_applications')
      .insert({
        job_id: jobId,
        candidate_id: candidateId,
        idempotency_key: idempotencyKey,
      })
      .select('id, job_id, candidate_id, status, created_at')
      .single();
    if (insertError) {
      // A concurrent request may have inserted first -- the unique
      // constraint on (job_id, candidate_id) is the real idempotency
      // guarantee; fall back to reading what won the race.
      const { data: winner } = await this.supabase.admin
        .from('job_applications')
        .select('id, job_id, candidate_id, status, created_at')
        .eq('job_id', jobId)
        .eq('candidate_id', candidateId)
        .maybeSingle();
      if (winner) {
        return { application: winner, created: false };
      }
      throw new Error(`Failed to create application: ${insertError.message}`);
    }

    return { application: created, created: true };
  }

  private async hasActiveEmployerSharingConsent(
    candidateId: string,
  ): Promise<boolean> {
    const { data, error } = await this.supabase.admin
      .from('consent_grants')
      .select('id')
      .eq('candidate_id', candidateId)
      .eq('purpose', EMPLOYER_SHARING_CONSENT_PURPOSE)
      .is('revoked_at', null)
      .limit(1)
      .maybeSingle();
    if (error) {
      throw new Error(`Failed to check consent: ${error.message}`);
    }
    return data != null;
  }
}
