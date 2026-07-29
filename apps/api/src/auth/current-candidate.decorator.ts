import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { AuthenticatedRequest } from './candidate-auth.guard';

/** Only valid on routes guarded by CandidateAuthGuard. */
export const CurrentCandidate = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): string => {
    const request = ctx.switchToHttp().getRequest<AuthenticatedRequest>();
    return request.candidateId;
  },
);
