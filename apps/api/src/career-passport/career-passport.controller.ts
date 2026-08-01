import { Controller, Get, HttpStatus, Param, Res } from '@nestjs/common';
import { Response } from 'express';
import { renderShareLinkUnavailablePage, renderSharedEvidencePage } from './career-passport-page';
import { CareerPassportService } from './career-passport.service';

/**
 * The public share-link surface: unauthenticated by design (anyone with
 * the token can view it -- that's the point), so this must never expose
 * anything beyond what `CareerPassportService.resolveShareLink` already
 * scoped to the grant. No other career-passport route exists here; minting
 * and revoking a link stays candidate-authenticated and goes straight to
 * Supabase from the app (see `wms_career_passport_repository.dart`),
 * mirroring how `career_passport_sharing` consent is already managed.
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
}
