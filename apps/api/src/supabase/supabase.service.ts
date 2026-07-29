import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

/**
 * Holds the one Supabase client this service is allowed to use: the
 * service-role client. It bypasses row-level security by design, so every
 * query written against it must enforce its own authorization -- see
 * jobs.service.ts for the pattern (always filter by the caller's
 * candidate_id, never trust a client-supplied id).
 *
 * The service-role key must never be sent to any client. See
 * docs/03-api-specifications.md "API Security".
 */
@Injectable()
export class SupabaseService implements OnModuleInit {
  private client!: SupabaseClient;

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    const url = this.config.get<string>('SUPABASE_URL');
    const serviceRoleKey = this.config.get<string>(
      'SUPABASE_SERVICE_ROLE_KEY',
    );
    if (!url || !serviceRoleKey) {
      throw new Error(
        'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set. See apps/api/.env.example.',
      );
    }
    this.client = createClient(url, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
  }

  get admin(): SupabaseClient {
    return this.client;
  }

  /**
   * Verifies a candidate's bearer token by asking Supabase Auth, rather than
   * decoding the JWT locally -- this also catches revoked/expired sessions.
   */
  async verifyCandidateToken(token: string): Promise<string | null> {
    const { data, error } = await this.client.auth.getUser(token);
    if (error || !data.user) return null;
    return data.user.id;
  }
}
