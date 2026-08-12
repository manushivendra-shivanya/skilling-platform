import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { CandidateAuthGuard } from '../auth/candidate-auth.guard';
import { CurrentCandidate } from '../auth/current-candidate.decorator';
import { ResumeParseRequestBody, ResumeService } from './resume.service';

@Controller('resume')
export class ResumeController {
  constructor(private readonly resume: ResumeService) {}

  @Post('parse')
  @UseGuards(CandidateAuthGuard)
  async parse(
    @CurrentCandidate() candidateId: string,
    @Body() body: ResumeParseRequestBody,
  ) {
    return this.resume.parseResume(candidateId, body);
  }
}
