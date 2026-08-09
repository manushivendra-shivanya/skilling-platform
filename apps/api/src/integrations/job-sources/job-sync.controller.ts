import { Controller, Headers, Post, UnauthorizedException } from '@nestjs/common';
import { JobSyncService } from './job-sync.service';

/**
 * Triggered by Vercel Cron (see `vercel.json`'s `crons` array), not by an
 * in-process `@Cron` timer -- Vercel's serverless model has no persistent
 * process for an in-process scheduler to live in (each invocation is its
 * own short-lived function), so the actual schedule now lives in
 * `vercel.json` and this endpoint is what it calls. Replaces
 * `JobSyncScheduler`, which only made sense on a Render-style
 * always-running process.
 *
 * Vercel automatically sends `Authorization: Bearer $CRON_SECRET` on
 * scheduled invocations when `CRON_SECRET` is set as a project env var --
 * this guard rejects anything that doesn't present it, so the route can't
 * be used by an outside caller to trigger an unbounded external-API sync
 * on demand (that's still `POST /v1/dev/job-sync`, gated separately).
 */
@Controller('internal/cron')
export class JobSyncCronController {
  constructor(private readonly jobSync: JobSyncService) {}

  @Post('job-sync')
  async trigger(@Headers('authorization') authHeader?: string) {
    const expected = process.env.CRON_SECRET;
    if (!expected || authHeader !== `Bearer ${expected}`) {
      throw new UnauthorizedException();
    }
    return { results: await this.jobSync.syncAll('cron') };
  }
}
