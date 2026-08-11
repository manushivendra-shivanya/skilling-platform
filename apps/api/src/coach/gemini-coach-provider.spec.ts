import { GoogleGenAI } from '@google/genai';
import { GEMINI_COACH_MODEL_ID, GeminiCoachProvider } from './gemini-coach-provider';

/**
 * A minimal fake of the one method this provider actually calls --
 * `ai.models.generateContent` -- same posture as AdzunaAdapter's fake
 * fetcher in adzuna.adapter.spec.ts. Cast through `unknown` rather than
 * constructing a real GoogleGenAI, since the provider never touches
 * anything else on the client.
 */
function fakeClient(
  generateContent: (params: unknown) => Promise<{ text: string | undefined }>,
): GoogleGenAI {
  return { models: { generateContent } } as unknown as GoogleGenAI;
}

describe('GeminiCoachProvider', () => {
  it('maps candidate/coach history into Gemini user/model contents and returns the reply text', async () => {
    let seenParams: unknown;
    const client = fakeClient(async (params) => {
      seenParams = params;
      return { text: '  Break the task into steps.  ' };
    });
    const provider = new GeminiCoachProvider(client);

    const reply = await provider.generateReply({
      systemPrompt: 'You are the coach.',
      history: [
        { role: 'candidate', text: 'How do I prepare?' },
        { role: 'coach', text: 'Start with the basics.' },
      ],
    });

    expect(reply).toEqual({
      text: 'Break the task into steps.',
      modelId: GEMINI_COACH_MODEL_ID,
    });
    expect(seenParams).toEqual({
      model: GEMINI_COACH_MODEL_ID,
      contents: [
        { role: 'user', parts: [{ text: 'How do I prepare?' }] },
        { role: 'model', parts: [{ text: 'Start with the basics.' }] },
      ],
      config: { systemInstruction: 'You are the coach.', maxOutputTokens: 500 },
    });
  });

  it('throws when Gemini returns an empty or whitespace-only reply', async () => {
    const client = fakeClient(async () => ({ text: '   ' }));
    const provider = new GeminiCoachProvider(client);

    await expect(
      provider.generateReply({ systemPrompt: 'x', history: [] }),
    ).rejects.toThrow('Gemini returned an empty reply.');
  });
});
