import { Injectable } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { JobSyncService } from './job-sync.service';

/**
 * Auto-syncs roughly monthly, not on a tight cron -- with 8 query terms
 * per keyword-searched source and Jooble's free-tier key capped at 500
 * total requests, a 6-hourly cron would exhaust that quota in days for no
 * real benefit (job listings don't change that fast).
 *
 * `@Cron`, not `@Interval`: an `@Interval(30 * 24 * 60 * 60 * 1000)` was
 * tried first and is a real bug worth recording -- Node's timer APIs
 * (`setInterval` under `@Interval`) silently overflow past the 32-bit
 * signed integer max (~24.8 days); 30 days in ms exceeds that and Node
 * clamps the duration to 1ms instead of throwing, which would have fired
 * the sync almost immediately and continuously rather than monthly,
 * confirmed live via `TimeoutOverflowWarning` on boot. `@Cron` is
 * evaluated by a real cron scheduler, not a raw JS timer, so it has no
 * such ceiling.
 *
 * A fresh sync is also always available on demand via the existing
 * `POST /v1/dev/job-sync` manual trigger, which is the expected way to
 * force a refresh between auto-syncs.
 */
@Injectable()
export class JobSyncScheduler {
  constructor(private readonly jobSync: JobSyncService) {}

  @Cron(CronExpression.EVERY_1ST_DAY_OF_MONTH_AT_MIDNIGHT)
  async handleScheduledSync(): Promise<void> {
    await this.jobSync.syncAll('cron');
  }
}
