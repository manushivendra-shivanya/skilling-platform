/**
 * One neutral shape both providers translate into their own SDK's message
 * format. Kept intentionally minimal -- the coach has no memory of its own
 * (see coach.service.ts), so this `history` is entirely client-supplied on
 * every call and never persisted server-side.
 */
export interface CoachTurn {
  role: 'candidate' | 'coach';
  text: string;
}

export interface CoachReply {
  text: string;
  /** Recorded for auditability -- see docs/25's Phase J precedent. */
  modelId: string;
}

export interface GenerateReplyParams {
  systemPrompt: string;
  history: CoachTurn[];
}

/**
 * Implemented by GeminiCoachProvider (active/default) and
 * AnthropicCoachProvider (configured, switchable via COACH_MODEL_PROVIDER).
 * CoachService depends only on this interface, never on a concrete SDK
 * client, so swapping the active provider is a config change, not a code
 * change.
 */
export interface CoachAiProvider {
  readonly id: string;
  generateReply(params: GenerateReplyParams): Promise<CoachReply>;
}
