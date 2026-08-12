import Anthropic from '@anthropic-ai/sdk';
import {
  ANTHROPIC_COACH_MODEL_ID,
  AnthropicCoachProvider,
} from './anthropic-coach-provider';

/**
 * A minimal fake of the one method this provider actually calls --
 * `client.messages.create` -- same posture as GeminiCoachProvider's fake
 * client (see gemini-coach-provider.spec.ts).
 */
function fakeClient(
  create: (params: unknown) => Promise<{ content: unknown[] }>,
): Anthropic {
  return { messages: { create } } as unknown as Anthropic;
}

describe('AnthropicCoachProvider', () => {
  it('maps candidate/coach history into user/assistant messages, disables thinking, and returns the reply text', async () => {
    let seenParams: unknown;
    const client = fakeClient(async (params) => {
      seenParams = params;
      return { content: [{ type: 'text', text: '  Break the task into steps.  ' }] };
    });
    const provider = new AnthropicCoachProvider(client);

    const reply = await provider.generateReply({
      systemPrompt: 'You are the coach.',
      history: [
        { role: 'candidate', text: 'How do I prepare?' },
        { role: 'coach', text: 'Start with the basics.' },
      ],
    });

    expect(reply).toEqual({
      text: 'Break the task into steps.',
      modelId: ANTHROPIC_COACH_MODEL_ID,
    });
    expect(seenParams).toEqual({
      model: ANTHROPIC_COACH_MODEL_ID,
      max_tokens: 500,
      system: 'You are the coach.',
      thinking: { type: 'disabled' },
      messages: [
        { role: 'user', content: 'How do I prepare?' },
        { role: 'assistant', content: 'Start with the basics.' },
      ],
    });
  });

  it('throws when Claude returns no text block', async () => {
    const client = fakeClient(async () => ({
      content: [{ type: 'tool_use' }],
    }));
    const provider = new AnthropicCoachProvider(client);

    await expect(
      provider.generateReply({ systemPrompt: 'x', history: [] }),
    ).rejects.toThrow('Claude returned an empty reply.');
  });
});
