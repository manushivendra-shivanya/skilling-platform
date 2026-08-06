import { Injectable } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { JobSyncService } from './job-sync.service';

@Injectable()
export class JobSyncScheduler {
  constructor(private readonly jobSync: JobSyncService) {}

  @Cron(CronExpression.EVERY_6_HOURS)
  async handleScheduledSync(): Promise<void> {
    await this.jobSync.syncAll('cron');
  }
}
