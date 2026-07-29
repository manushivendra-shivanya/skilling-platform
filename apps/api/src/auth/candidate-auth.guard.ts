import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { AppError } from '../common/app-error';
import { SupabaseService } from '../supabase/supabase.service';

export interface AuthenticatedRequest {
  candidateId: string;
}

@Injectable()
export class CandidateAuthGuard implements CanActivate {
  constructor(private readonly supabase: SupabaseService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context
      .switchToHttp()
      .getRequest<AuthenticatedRequest & { headers: Record<string, string> }>();
    const header = request.headers['authorization'];
    const token = header?.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) {
      throw AppError.unauthenticated();
    }
    const candidateId = await this.supabase.verifyCandidateToken(token);
    if (!candidateId) {
      throw AppError.unauthenticated('Your session has expired. Sign in again.');
    }
    request.candidateId = candidateId;
    return true;
  }
}
