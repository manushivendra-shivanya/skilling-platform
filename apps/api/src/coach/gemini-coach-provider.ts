import { GoogleGenAI } from '@google/genai';
import {
  CoachAiProvider,
  CoachReply,
  GenerateReplyParams,
} from './coach-ai-provider';

// Recorded here (not just in .env.example) because it feeds `modelId` on
// every reply for auditability -- see docs/25's Phase J precedent.
export const GEMINI_COACH_MODEL_ID = 'gemini-2.5-flash';

/**
 * Active/default coach provider (see COACH_MODEL_PROVIDER in
 * coach.module.ts). Stateless by construction: every call rebuilds the
 * full turn history from `params.history` via `ai.models.generateContent`
 * rather than the SDK's stateful `ai.chats` wrapper, because this backend
 * persists nothing between requests -- see docs/25 and the coach's
 * ephemeral-history decision.
 *
 * The GoogleGenAI client is injected (see coach.module.ts's useFactory) so
 * tests can substitute a fake with a mocked `.models.generateContent` --
 * same pattern as AdzunaAdapter's injected HttpFetcher.
 */
export class GeminiCoachProvider implements CoachAiProvider {
  readonly id = 'gemini';

  constructor(private readonly client: GoogleGenAI) {}

  async generateReply({
    systemPrompt,
    history,
  }: GenerateReplyParams): Promise<CoachReply> {
    const contents = history.map((turn) => ({
      role: turn.role === 'candidate' ? 'user' : 'model',
      parts: [{ text: turn.text }],
    }));

    const response = await this.client.models.generateContent({
      model: GEMINI_COACH_MODEL_ID,
      contents,
      config: { systemInstruction: systemPrompt, maxOutputTokens: 500 },
    });

    const text = response.text?.trim();
    if (!text) {
      throw new Error('Gemini returned an empty reply.');
    }
    return { text, modelId: GEMINI_COACH_MODEL_ID };
  }
}
