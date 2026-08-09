import {
  Body,
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
import { ShiftsService } from './shifts.service';

@Controller('shifts')
@UseGuards(CandidateAuthGuard)
export class ShiftsController {
  constructor(private readonly shifts: ShiftsService) {}

  @Get()
  async list() {
    return { shifts: await this.shifts.listPublished() };
  }

  @Get('applications')
  async myApplications(@CurrentCandidate() candidateId: string) {
    return {
      applications: await this.shifts.listApplicationsForCandidate(candidateId),
    };
  }

  @Get(':id')
  async detail(@Param('id') shiftId: string) {
    return { shift: await this.shifts.getById(shiftId) };
  }

  @Post(':id/applications')
  @HttpCode(200)
  async apply(
    @Param('id') shiftId: string,
    @CurrentCandidate() candidateId: string,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
    @Res({ passthrough: true }) res: Response,
  ) {
    if (!idempotencyKey) {
      throw AppError.validation('An Idempotency-Key header is required.');
    }
    const { application, created } = await this.shifts.applyToShift(
      candidateId,
      shiftId,
      idempotencyKey,
    );
    if (created) {
      res.status(201);
    }
    return { application };
  }

  @Post('applications/:id/check-in')
  async checkIn(
    @Param('id') applicationId: string,
    @CurrentCandidate() candidateId: string,
    @Body() body: { code?: string },
  ) {
    if (!body?.code?.trim()) {
      throw AppError.validation('A check-in code is required.');
    }
    return {
      application: await this.shifts.checkIn(
        candidateId,
        applicationId,
        body.code.trim(),
      ),
    };
  }

  @Post('applications/:id/check-out')
  async checkOut(
    @Param('id') applicationId: string,
    @CurrentCandidate() candidateId: string,
  ) {
    return {
      application: await this.shifts.checkOut(candidateId, applicationId),
    };
  }
}
