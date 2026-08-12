import { CoachAiProvider, CoachReply } from './coach-ai-provider';

/**
 * Stand-in used when the selected COACH_MODEL_PROVIDER has no API key set
 * yet (e.g. GEMINI_API_KEY unset before the user has obtained one -- see
 * apps/api/.env.example). Exists so a missing key degrades to a clean,
 * catchable 503 on the one endpoint that needs it, rather than crashing
 * the whole API at boot the way SupabaseService's required vars do.
 */
export class UnconfiguredCoachProvider implements CoachAiProvider {
  readonly id = 'unconfigured';

  async generateReply(): Promise<CoachReply> {
    throw new Error(
      'No AI coach provider is configured. Set GEMINI_API_KEY (or ' +
        'ANTHROPIC_API_KEY with COACH_MODEL_PROVIDER=anthropic) in ' +
        'apps/api/.env.',
    );
  }
}
