import { Controller, Get } from '@nestjs/common';

/**
 * Deliberately unauthenticated and does no work beyond returning a literal.
 * Two uses: (1) Render's own health-check probe for this service, and (2)
 * a "wake up" ping the mobile app fires as soon as sign-in starts, so a
 * cold Render instance (Free tier spins down after inactivity) starts
 * booting as early as possible instead of only on the first real,
 * auth-guarded request.
 */
@Controller('health')
export class HealthController {
  @Get()
  check() {
    return { status: 'ok' };
  }
}
