import { HttpException, HttpStatus } from '@nestjs/common';

/**
 * Every error thrown by application code should be an AppError so the
 * response matches the stable machine-code envelope in
 * docs/03-api-specifications.md. Nest's own framework exceptions (e.g. a
 * malformed route) are handled separately by AppExceptionFilter.
 */
export class AppError extends HttpException {
  constructor(
    public readonly code: string,
    message: string,
    status: HttpStatus,
    public readonly details: Record<string, unknown> = {},
  ) {
    super(message, status);
  }

  static unauthenticated(message = 'Sign in to continue.') {
    return new AppError('UNAUTHENTICATED', message, HttpStatus.UNAUTHORIZED);
  }

  static notFound(code: string, message: string) {
    return new AppError(code, message, HttpStatus.NOT_FOUND);
  }

  static consentRequired(message: string) {
    return new AppError('CONSENT_REQUIRED', message, HttpStatus.FORBIDDEN);
  }

  static forbidden(code: string, message: string) {
    return new AppError(code, message, HttpStatus.FORBIDDEN);
  }

  static validation(message: string, details: Record<string, unknown> = {}) {
    return new AppError(
      'VALIDATION_ERROR',
      message,
      HttpStatus.BAD_REQUEST,
      details,
    );
  }

  static rateLimited(message: string) {
    return new AppError('RATE_LIMITED', message, HttpStatus.TOO_MANY_REQUESTS);
  }

  static serviceUnavailable(code: string, message: string) {
    return new AppError(code, message, HttpStatus.SERVICE_UNAVAILABLE);
  }
}
