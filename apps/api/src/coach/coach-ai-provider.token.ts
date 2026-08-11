/**
 * Injection token for whichever CoachAiProvider COACH_MODEL_PROVIDER
 * selects at module-construction time -- see coach.module.ts. CoachService
 * depends on this token, never on GeminiCoachProvider/AnthropicCoachProvider
 * directly, so it stays unaware of which one is actually active.
 */
export const COACH_AI_PROVIDER = 'COACH_AI_PROVIDER';
