import { readFileSync } from 'fs';
import { join } from 'path';
import { Controller, Get, NotFoundException, Res } from '@nestjs/common';
import { Response } from 'express';

const HARNESS_PATH = join(__dirname, 'employer-review-harness.html');

/**
 * Internal-only QC surface -- never the employer portal. Every route here
 * must 404 when NODE_ENV=production; this is not an authorization
 * mechanism, only a guarantee this never reaches a deployed environment
 * unintentionally.
 */
@Controller('dev')
export class DevController {
  @Get('employer-review')
  employerReviewHarness(@Res() res: Response) {
    if (process.env.NODE_ENV === 'production') {
      throw new NotFoundException();
    }
    res.type('html').send(readFileSync(HARNESS_PATH, 'utf8'));
  }
}
