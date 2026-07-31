import {
  Body,
  Controller,
  Headers,
  HttpCode,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { CandidateAuthGuard } from '../auth/candidate-auth.guard';
import { CurrentCandidate } from '../auth/current-candidate.decorator';
import { AppError } from '../common/app-error';
import { WorkplaceSimulationService } from './workplace-simulation.service';
import { WmsSyncRequest } from './workplace-simulation.types';

@Controller('workplace-simulation')
@UseGuards(CandidateAuthGuard)
export class WorkplaceSimulationController {
  constructor(private readonly workplace: WorkplaceSimulationService) {}

  @Post('attempts/:attemptId/sync')
  @HttpCode(200)
  async syncAttempt(
    @Param('attemptId') attemptId: string,
    @CurrentCandidate() candidateId: string,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
    @Body() body: WmsSyncRequest,
  ) {
    if (!idempotencyKey) {
      throw AppError.validation('An Idempotency-Key header is required.');
    }
    return {
      sync: await this.workplace.syncAttempt(candidateId, attemptId, body),
    };
  }
}
