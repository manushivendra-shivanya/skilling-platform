import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { CandidateAuthGuard } from '../auth/candidate-auth.guard';
import { CurrentCandidate } from '../auth/current-candidate.decorator';
import { CoachMessageRequest, CoachService } from './coach.service';

@Controller('coach')
export class CoachController {
  constructor(private readonly coach: CoachService) {}

  @Post('message')
  @UseGuards(CandidateAuthGuard)
  async sendMessage(
    @CurrentCandidate() candidateId: string,
    @Body() body: CoachMessageRequest,
  ) {
    return this.coach.sendMessage(candidateId, body);
  }
}
