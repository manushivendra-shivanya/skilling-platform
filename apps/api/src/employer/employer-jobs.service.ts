import { Injectable } from '@nestjs/common';
import { AppError } from '../common/app-error';
import { SupabaseService } from '../supabase/supabase.service';

export interface EmployerJob {
  id: string;
  title: string;
  location: string;
  description: string;
  status: string;
  publishedAt: string | null;
  createdAt: string;
}

export interface EmployerJobWithApplicationCount extends EmployerJob {
  applicationCount: number;
}

interface JobRow {
  id: string;
  title: string;
  location: string;
  description: string;
  status: string;
  published_at: string | null;
  created_at: string;
}

function toEmployerJob(row: JobRow): EmployerJob {
  return {
    id: row.id,
    title: row.title,
    location: row.location,
    description: row.description,
    status: row.status,
    publishedAt: row.published_at,
    createdAt: row.created_at,
  };
}

const JOB_COLUMNS =
  'id, title, location, description, status, published_at, created_at';

/**
 * Direct employer job posting -- Flora-native jobs (`source: 'flora'`,
 * `apply_url: null`), distinct from the read-only aggregator mirrors
 * `JobSyncService` writes. Authorization follows the exact scoping
 * pattern `EmployerService` already uses: every read/write is filtered by
 * `.eq('employer_id', employerId)`, so a job belonging to another
 * employer is indistinguishable from a nonexistent one -- see
 * `findOwnedJob`, mirroring `EmployerService.findAccessibleApplication`.
 */
@Injectable()
export class EmployerJobsService {
  constructor(private readonly supabase: SupabaseService) {}

  async createDraft(
    employerId: string,
    input: {
      title: string;
      location: string;
      description: string;
      roleProfileId: string | null;
    },
  ): Promise<EmployerJob> {
    const employerName = await this.employerName(employerId);
    const { data, error } = await this.supabase.admin
      .from('jobs')
      .insert({
        employer_id: employerId,
        employer_name: employerName,
        title: input.title,
        location: input.location,
        description: input.description,
        role_profile_id: input.roleProfileId,
        status: 'draft',
        source: 'flora',
      })
      .select(JOB_COLUMNS)
      .single();
    if (error) {
      if (error.code === '23503') {
        throw AppError.validation(
          'roleProfileId does not match a published role profile.',
        );
      }
      throw new Error(`Failed to create job: ${error.message}`);
    }
    return toEmployerJob(data);
  }

  async publish(employerId: string, jobId: string): Promise<EmployerJob> {
    const job = await this.findOwnedJob(employerId, jobId);
    if (!job) {
      throw AppError.notFound('JOB_NOT_FOUND', 'Job not found.');
    }
    if (job.status === 'closed') {
      throw AppError.validation('Cannot publish a closed job.');
    }
    if (job.status === 'published') {
      return toEmployerJob(job);
    }

    const { data, error } = await this.supabase.admin
      .from('jobs')
      .update({ status: 'published', published_at: new Date().toISOString() })
      .eq('id', jobId)
      .eq('employer_id', employerId)
      .select(JOB_COLUMNS)
      .single();
    if (error) {
      throw new Error(`Failed to publish job: ${error.message}`);
    }
    return toEmployerJob(data);
  }

  async listOwn(employerId: string): Promise<EmployerJobWithApplicationCount[]> {
    const { data: jobs, error } = await this.supabase.admin
      .from('jobs')
      .select(JOB_COLUMNS)
      .eq('employer_id', employerId)
      .order('created_at', { ascending: false });
    if (error) {
      throw new Error(`Failed to load jobs: ${error.message}`);
    }
    if (!jobs?.length) return [];

    const { data: applications, error: applicationsError } =
      await this.supabase.admin
        .from('job_applications')
        .select('job_id')
        .in(
          'job_id',
          jobs.map((job: JobRow) => job.id),
        )
        .neq('status', 'withdrawn');
    if (applicationsError) {
      throw new Error(
        `Failed to load application counts: ${applicationsError.message}`,
      );
    }

    const counts = new Map<string, number>();
    for (const row of (applications ?? []) as { job_id: string }[]) {
      counts.set(row.job_id, (counts.get(row.job_id) ?? 0) + 1);
    }
    return jobs.map((job: JobRow) => ({
      ...toEmployerJob(job),
      applicationCount: counts.get(job.id) ?? 0,
    }));
  }

  private async findOwnedJob(
    employerId: string,
    jobId: string,
  ): Promise<JobRow | null> {
    const { data, error } = await this.supabase.admin
      .from('jobs')
      .select(JOB_COLUMNS)
      .eq('id', jobId)
      .eq('employer_id', employerId)
      .maybeSingle();
    if (error) {
      throw new Error(`Failed to load job: ${error.message}`);
    }
    return data;
  }

  private async employerName(employerId: string): Promise<string> {
    const { data, error } = await this.supabase.admin
      .from('employers')
      .select('name')
      .eq('id', employerId)
      .single();
    if (error) {
      throw new Error(`Failed to resolve employer name: ${error.message}`);
    }
    return data.name;
  }
}
