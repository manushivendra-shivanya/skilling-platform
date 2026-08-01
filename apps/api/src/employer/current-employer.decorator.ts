import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { AuthenticatedEmployerRequest } from './employer-auth.guard';

/** Only valid on routes guarded by EmployerAuthGuard. */
export const CurrentEmployer = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): string => {
    const request = ctx
      .switchToHttp()
      .getRequest<AuthenticatedEmployerRequest>();
    return request.employerId;
  },
);
