import Anthropic from '@anthropic-ai/sdk';
import {
  CoachAiProvider,
  CoachReply,
  GenerateReplyParams,
} from './coach-ai-provider';

// User-specified model (see the claude-api skill's own exception clause:
// "ALWAYS use claude-opus-5 unless the user explicitly names a different
// model"). Recorded here so it feeds `modelId` on every reply.
export const ANTHROPIC_COACH_MODEL_ID = 'claude-sonnet-5';

/**
 * Configured now, held as a fallback -- COACH_MODEL_PROVIDER defaults to
 * "gemini" (see coach.module.ts). Not wired to any traffic until that env
 * var is switched, but built and tested to the same standard so the
 * switch is a config change, not a future implementation task.
 *
 * `thinking: { type: "disabled" }` is deliberate: a coach reply is a short
 * conversational turn, not a reasoning-heavy task, and disabling thinking
 * keeps latency and cost down for that shape of request.
 */
export class AnthropicCoachProvider implements CoachAiProvider {
  readonly id = 'anthropic';

  constructor(private readonly client: Anthropic) {}

  async generateReply({
    systemPrompt,
    history,
  }: GenerateReplyParams): Promise<CoachReply> {
    const messages = history.map((turn) => ({
      role: turn.role === 'candidate' ? ('user' as const) : ('assistant' as const),
      content: turn.text,
    }));

    const response = await this.client.messages.create({
      model: ANTHROPIC_COACH_MODEL_ID,
      max_tokens: 500,
      system: systemPrompt,
      thinking: { type: 'disabled' },
      messages,
    });

    const textBlock = response.content.find(
      (block): block is Anthropic.TextBlock => block.type === 'text',
    );
    const text = textBlock?.text.trim() ?? '';
    if (!text) {
      throw new Error('Claude returned an empty reply.');
    }
    return { text, modelId: ANTHROPIC_COACH_MODEL_ID };
  }
}
