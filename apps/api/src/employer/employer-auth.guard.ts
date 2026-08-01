import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { AppError } from '../common/app-error';
import { SupabaseService } from '../supabase/supabase.service';
import { hashApiKey } from './api-key-hash';

export interface AuthenticatedEmployerRequest {
  employerId: string;
  employerName: string;
}

/**
 * There is no employer login flow -- an employer authenticates with a
 * static API key issued out-of-band (seeded directly into `employers` for
 * this MVP). This guard is the entire trust boundary: it never trusts a
 * client-supplied employer id, only what the key hash resolves to.
 */
@Injectable()
export class EmployerAuthGuard implements CanActivate {
  constructor(private readonly supabase: SupabaseService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context
      .switchToHttp()
      .getRequest<
        AuthenticatedEmployerRequest & { headers: Record<string, string> }
      >();
    const header = request.headers['authorization'];
    const key = header?.startsWith('Bearer ') ? header.slice(7) : null;
    if (!key) {
      throw AppError.unauthenticated('An employer API key is required.');
    }
    const { data, error } = await this.supabase.admin
      .from('employers')
      .select('id, name')
      .eq('api_key_hash', hashApiKey(key))
      .maybeSingle();
    if (error) {
      throw new Error(`Failed to verify employer API key: ${error.message}`);
    }
    if (!data) {
      throw AppError.unauthenticated('Invalid employer API key.');
    }
    request.employerId = data.id;
    request.employerName = data.name;
    return true;
  }
}
