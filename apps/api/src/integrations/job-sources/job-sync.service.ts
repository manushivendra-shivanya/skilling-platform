import { Inject, Injectable } from '@nestjs/common';
import { AppError } from '../../common/app-error';
import { SupabaseService } from '../../supabase/supabase.service';
import { JobSourceAdapter } from './job-source-adapter';
import { JOB_SOURCE_ADAPTERS } from './job-source-adapters.token';

export interface JobSyncRunResult {
  source: string;
  ok: boolean;
  jobsSeen: number;
  jobsUpserted: number;
  error?: string;
}

type TriggeredBy = 'cron' | 'manual';

/**
 * Syncs every configured job source into `public.jobs`, one adapter at a
 * time. Each adapter's failure is isolated -- see `syncOne` -- so one
 * source erroring (or simply not being configured yet) never prevents the
 * others from syncing.
 */
@Injectable()
export class JobSyncService {
  constructor(
    @Inject(JOB_SOURCE_ADAPTERS)
    private readonly adapters: JobSourceAdapter[],
    private readonly supabase: SupabaseService,
  ) {}

  async syncAll(triggeredBy: TriggeredBy = 'cron'): Promise<JobSyncRunResult[]> {
    return Promise.all(
      this.adapters.map((adapter) => this.syncOne(adapter, triggeredBy)),
    );
  }

  async syncSource(
    key: string,
    triggeredBy: TriggeredBy = 'cron',
  ): Promise<JobSyncRunResult> {
    const adapter = this.adapters.find((a) => a.key === key);
    if (!adapter) {
      throw AppError.notFound(
        'JOB_SOURCE_NOT_FOUND',
        `Unknown job source "${key}".`,
      );
    }
    return this.syncOne(adapter, triggeredBy);
  }

  /**
   * Never rejects -- both the fetch/upsert failure *and* the audit-row
   * write are caught internally. That is what makes `Promise.all` over
   * every adapter in `syncAll` safe: a failed audit-row insert must not
   * turn an otherwise-successful adapter's result into a lost rejection
   * that drags its siblings' already-computed results down with it.
   */
  private async syncOne(
    adapter: JobSourceAdapter,
    triggeredBy: TriggeredBy,
  ): Promise<JobSyncRunResult> {
    const startedAt = new Date();
    let result: JobSyncRunResult;
    try {
      const listings = await adapter.fetchJobs();
      let jobsUpserted = 0;
      if (listings.length > 0) {
        const rows = listings.map((listing) => ({
          source: adapter.key,
          external_id: listing.externalId,
          employer_name: listing.employerName,
          title: listing.title,
          location: listing.location,
          description: listing.description,
          apply_url: listing.applyUrl,
          status: 'published',
          published_at: new Date().toISOString(),
        }));
        const { error } = await this.supabase.admin
          .from('jobs')
          .upsert(rows, { onConflict: 'source,external_id' });
        if (error) {
          throw new Error(
            `Failed to upsert jobs for ${adapter.key}: ${error.message}`,
          );
        }
        jobsUpserted = rows.length;
      }
      result = {
        source: adapter.key,
        ok: true,
        jobsSeen: listings.length,
        jobsUpserted,
      };
    } catch (error) {
      result = {
        source: adapter.key,
        ok: false,
        jobsSeen: 0,
        jobsUpserted: 0,
        error: error instanceof Error ? error.message : String(error),
      };
    }

    try {
      await this.supabase.admin.from('job_sync_runs').insert({
        source: adapter.key,
        triggered_by: triggeredBy,
        started_at: startedAt.toISOString(),
        jobs_seen: result.jobsSeen,
        jobs_upserted: result.jobsUpserted,
        error: result.error ?? null,
      });
    } catch (auditError) {
      // eslint-disable-next-line no-console
      console.error(
        `Failed to record job_sync_runs row for ${adapter.key}`,
        auditError,
      );
    }
    return result;
  }
}
