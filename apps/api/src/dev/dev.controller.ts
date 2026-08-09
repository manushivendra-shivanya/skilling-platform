import { readFileSync } from 'fs';
import { join } from 'path';
import {
  Controller,
  Get,
  NotFoundException,
  Post,
  Query,
  Res,
} from '@nestjs/common';
import { Response } from 'express';
import { JobSyncService } from '../integrations/job-sources/job-sync.service';

const HARNESS_PATH = join(__dirname, 'employer-review-harness.html');

/**
 * Internal-only QC surface -- never the employer portal. Every route here
 * must 404 when NODE_ENV=production; this is not an authorization
 * mechanism, only a guarantee this never reaches a deployed environment
 * unintentionally.
 */
@Controller('dev')
export class DevController {
  constructor(private readonly jobSync: JobSyncService) {}

  @Get('employer-review')
  employerReviewHarness(@Res() res: Response) {
    if (process.env.NODE_ENV === 'production') {
      throw new NotFoundException();
    }
    res.type('html').send(readFileSync(HARNESS_PATH, 'utf8'));
  }

  /**
   * Triggers a job source sync on demand in development, without waiting
   * for the scheduled sync -- e.g. `POST /v1/dev/job-sync` (all sources)
   * or `POST /v1/dev/job-sync?source=adzuna` (one source). This route
   * 404s in production like every other route in this controller; the
   * production schedule is a Vercel Cron Job calling
   * `POST /v1/internal/cron/job-sync` (see `JobSyncCronController` and
   * `vercel.json`), not this route.
   */
  @Post('job-sync')
  async triggerJobSync(@Query('source') source?: string) {
    if (process.env.NODE_ENV === 'production') {
      throw new NotFoundException();
    }
    return source
      ? { result: await this.jobSync.syncSource(source, 'manual') }
      : { results: await this.jobSync.syncAll('manual') };
  }
}
