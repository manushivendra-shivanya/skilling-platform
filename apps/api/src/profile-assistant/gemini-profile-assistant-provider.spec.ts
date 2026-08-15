import { GoogleGenAI } from '@google/genai';
import {
  GEMINI_PROFILE_ASSISTANT_MODEL_ID,
  GeminiProfileAssistantProvider,
  buildPrompt,
} from './gemini-profile-assistant-provider';
import { ContinueConversationParams } from './profile-assistant-ai-provider';

function fakeClient(text: string | undefined) {
  const generateContent = jest.fn().mockResolvedValue({ text });
  return {
    client: { models: { generateContent } } as unknown as GoogleGenAI,
    generateContent,
  };
}

const params: ContinueConversationParams = {
  knownProfileDigest: 'Name: Asha Kumari',
  remainingFields: ['noticePeriod', 'expectedCtc'],
  history: [{ role: 'candidate', text: 'Pandrah din chahiye' }],
  languageTag: 'hi_Latn',
};

describe('GeminiProfileAssistantProvider', () => {
  it('returns the assistant reply and the fields it extracted', async () => {
    const { client, generateContent } = fakeClient(
      JSON.stringify({
        text: 'Theek hai! Ab expected salary batayein?',
        isComplete: false,
        updates: [
          {
            field: 'noticePeriod',
            id: 'fifteen_days',
            confirmation: '15 days set kar diya',
          },
        ],
      }),
    );

    const reply = await new GeminiProfileAssistantProvider(
      client,
    ).continueConversation(params);

    expect(reply.text).toBe('Theek hai! Ab expected salary batayein?');
    expect(reply.isComplete).toBe(false);
    expect(reply.updates).toEqual([
      {
        field: 'noticePeriod',
        id: 'fifteen_days',
        confirmation: '15 days set kar diya',
      },
    ]);
    expect(reply.modelId).toBe(GEMINI_PROFILE_ASSISTANT_MODEL_ID);
    expect(generateContent).toHaveBeenCalledTimes(1);
  });

  it('drops an update whose value is structurally wrong, keeping the rest', async () => {
    const { client } = fakeClient(
      JSON.stringify({
        text: 'Aur kuch?',
        updates: [
          // Not one of NOTICE_PERIOD_IDS -- unusable, so dropped.
          { field: 'noticePeriod', id: 'next tuesday', confirmation: 'ok' },
          // Not a writable field at all.
          { field: 'workExperience', text: 'Associate', confirmation: 'ok' },
          // Zero is not a real expected salary.
          { field: 'expectedCtc', amount: 0, confirmation: 'ok' },
          { field: 'headline', text: 'Warehouse Associate', confirmation: 'ok' },
        ],
      }),
    );

    const reply = await new GeminiProfileAssistantProvider(
      client,
    ).continueConversation(params);

    expect(reply.updates).toHaveLength(1);
    expect(reply.updates[0].field).toBe('headline');
  });

  it('accepts an amount the model sent back as a numeric string', async () => {
    const { client } = fakeClient(
      JSON.stringify({
        text: 'Noted',
        updates: [
          { field: 'expectedCtc', amount: '320000', confirmation: 'ok' },
        ],
      }),
    );

    const reply = await new GeminiProfileAssistantProvider(
      client,
    ).continueConversation(params);

    expect(reply.updates[0].amount).toBe(320000);
  });

  it('degrades an unrecognised language proficiency instead of dropping the language', async () => {
    const { client } = fakeClient(
      JSON.stringify({
        text: 'Noted',
        updates: [
          {
            field: 'languages',
            languages: [
              { language: 'Hindi', proficiency: 'mother tongue' },
              { language: 'English', proficiency: 'fluent' },
            ],
            confirmation: 'ok',
          },
        ],
      }),
    );

    const reply = await new GeminiProfileAssistantProvider(
      client,
    ).continueConversation(params);

    expect(reply.updates[0].languages).toEqual([
      { language: 'Hindi', proficiency: 'elementary' },
      { language: 'English', proficiency: 'fluent' },
    ]);
  });

  it('strips a markdown fence around the JSON', async () => {
    const { client } = fakeClient(
      '```json\n{"text":"Namaste!","updates":[]}\n```',
    );

    const reply = await new GeminiProfileAssistantProvider(
      client,
    ).continueConversation(params);

    expect(reply.text).toBe('Namaste!');
  });

  it('throws on an empty response', async () => {
    const { client } = fakeClient(undefined);

    await expect(
      new GeminiProfileAssistantProvider(client).continueConversation(params),
    ).rejects.toThrow('empty');
  });

  it('throws on a non-JSON response', async () => {
    const { client } = fakeClient('I could not do that.');

    await expect(
      new GeminiProfileAssistantProvider(client).continueConversation(params),
    ).rejects.toThrow('non-JSON');
  });

  it('throws when the reply carries no text for the candidate', async () => {
    const { client } = fakeClient(JSON.stringify({ updates: [] }));

    await expect(
      new GeminiProfileAssistantProvider(client).continueConversation(params),
    ).rejects.toThrow('no text');
  });
});

describe('buildPrompt', () => {
  it('asks for Hinglish in Latin script for the hi_Latn locale', () => {
    expect(buildPrompt(params)).toContain('Hinglish');
    expect(buildPrompt(params)).toContain('Do NOT use Devanagari');
  });

  it('asks for Devanagari Hindi for the hi locale', () => {
    const prompt = buildPrompt({ ...params, languageTag: 'hi' });
    expect(prompt).toContain('Devanagari');
    expect(prompt).not.toContain('Hinglish');
  });

  it('lists what is already known so the assistant does not re-ask', () => {
    expect(buildPrompt(params)).toContain('Name: Asha Kumari');
    expect(buildPrompt(params)).toContain('noticePeriod, expectedCtc');
  });

  it('tells the model to greet first when there is no history', () => {
    const prompt = buildPrompt({ ...params, history: [] });
    expect(prompt).toContain('this is the first turn');
  });
});
