import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { CandidateAuthGuard } from '../auth/candidate-auth.guard';
import { CurrentCandidate } from '../auth/current-candidate.decorator';
import {
  ResumeDocumentParseRequestBody,
  ResumeParseRequestBody,
  ResumeService,
} from './resume.service';

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

  /**
   * Separate route rather than an optional field on `parse` so the two
   * request bodies stay separately validatable -- a client that sends
   * neither text nor a file gets a straight validation error from
   * whichever route it called, instead of one endpoint guessing what was
   * meant. Returns the identical response shape either way, so the mobile
   * review screen doesn't branch on how the resume arrived.
   */
  @Post('parse-document')
  @UseGuards(CandidateAuthGuard)
  async parseDocument(
    @CurrentCandidate() candidateId: string,
    @Body() body: ResumeDocumentParseRequestBody,
  ) {
    return this.resume.parseResumeDocument(candidateId, body);
  }
}
