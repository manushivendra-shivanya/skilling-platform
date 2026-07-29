import {
  Controller,
  Get,
  Headers,
  HttpCode,
  Param,
  Post,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Response } from 'express';
import { CandidateAuthGuard } from '../auth/candidate-auth.guard';
import { CurrentCandidate } from '../auth/current-candidate.decorator';
import { AppError } from '../common/app-error';
import { JobsService } from './jobs.service';

@Controller('jobs')
@UseGuards(CandidateAuthGuard)
export class JobsController {
  constructor(private readonly jobs: JobsService) {}

  @Get()
  async list() {
    return { jobs: await this.jobs.listPublishedJobs() };
  }

  @Post(':id/applications')
  @HttpCode(200)
  async apply(
    @Param('id') jobId: string,
    @CurrentCandidate() candidateId: string,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
    @Res({ passthrough: true }) res: Response,
  ) {
    if (!idempotencyKey) {
      throw AppError.validation('An Idempotency-Key header is required.');
    }
    const { application, created } = await this.jobs.applyToJob(
      candidateId,
      jobId,
      idempotencyKey,
    );
    if (created) {
      res.status(201);
    }
    return { application };
  }
}
