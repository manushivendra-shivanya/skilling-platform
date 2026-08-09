import { UnauthorizedException } from '@nestjs/common';
import { JobSyncCronController } from './job-sync.controller';
import { JobSyncRunResult, JobSyncService } from './job-sync.service';

describe('JobSyncCronController', () => {
  const originalSecret = process.env.CRON_SECRET;
  let jobSync: { syncAll: jest.Mock };
  let controller: JobSyncCronController;

  beforeEach(() => {
    process.env.CRON_SECRET = 'test-cron-secret';
    jobSync = { syncAll: jest.fn() };
    controller = new JobSyncCronController(jobSync as unknown as JobSyncService);
  });

  afterAll(() => {
    process.env.CRON_SECRET = originalSecret;
  });

  it('rejects a request with no authorization header', async () => {
    await expect(controller.trigger(undefined)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(jobSync.syncAll).not.toHaveBeenCalled();
  });

  it('rejects a request with the wrong secret', async () => {
    await expect(
      controller.trigger('Bearer not-the-secret'),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(jobSync.syncAll).not.toHaveBeenCalled();
  });

  it('rejects every request when CRON_SECRET is not configured, even a well-formed header', async () => {
    delete process.env.CRON_SECRET;
    await expect(
      controller.trigger('Bearer test-cron-secret'),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(jobSync.syncAll).not.toHaveBeenCalled();
  });

  it('runs the sync and returns its results when the secret matches', async () => {
    const results: JobSyncRunResult[] = [
      { source: 'adzuna', ok: true, jobsSeen: 3, jobsUpserted: 3 },
    ];
    jobSync.syncAll.mockResolvedValue(results);

    const response = await controller.trigger('Bearer test-cron-secret');

    expect(jobSync.syncAll).toHaveBeenCalledWith('cron');
    expect(response).toEqual({ results });
  });
});
