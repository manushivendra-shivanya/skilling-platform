import { Controller, Get, HttpStatus, Param, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { CandidateAuthGuard } from '../auth/candidate-auth.guard';
import { CurrentCandidate } from '../auth/current-candidate.decorator';
import { renderShareLinkUnavailablePage, renderSharedEvidencePage } from './career-passport-page';
import { CareerPassportService } from './career-passport.service';

/**
 * Two very different surfaces on one controller: `share/:token` is public
 * by design (anyone with the token can view it -- that's the point), so it
 * must never expose anything beyond what `resolveShareLink` already scoped
 * to the grant. `applied-employers` is candidate-authenticated -- the
 * `employers` table has no client-facing Supabase policy, so listing
 * "which employers could I grant Career Passport access to" has to go
 * through the BFF, unlike granting/revoking the grant itself, which goes
 * straight to Supabase from the app once the candidate has an employer id
 * in hand (see `wms_career_passport_repository.dart`).
 */
@Controller('career-passport')
export class CareerPassportController {
  constructor(private readonly careerPassport: CareerPassportService) {}

  @Get('share/:token')
  async share(@Param('token') token: string, @Res() res: Response) {
    const result = await this.careerPassport.resolveShareLink(token);
    if (result.status !== 'ok') {
      res
        .status(HttpStatus.NOT_FOUND)
        .type('html')
        .send(renderShareLinkUnavailablePage(result.status));
      return;
    }
    res.type('html').send(renderSharedEvidencePage(result.evidence));
  }

  @Get('applied-employers')
  @UseGuards(CandidateAuthGuard)
  async appliedEmployers(@CurrentCandidate() candidateId: string) {
    return { employers: await this.careerPassport.listAppliedEmployers(candidateId) };
  }
}
