import { GoogleGenAI } from '@google/genai';
import {
  GEMINI_RESUME_MODEL_ID,
  GeminiResumeParser,
} from './gemini-resume-parser';

/**
 * Same fake-client posture as coach/gemini-coach-provider.spec.ts -- a
 * minimal fake of the one method this parser actually calls.
 */
function fakeClient(
  generateContent: (params: unknown) => Promise<{ text: string | undefined }>,
): GoogleGenAI {
  return { models: { generateContent } } as unknown as GoogleGenAI;
}

const FULL_JSON = JSON.stringify({
  fullName: 'Asha Kumari',
  phone: '9876543210',
  email: 'asha@example.com',
  city: 'Lucknow',
  headline: 'Warehouse Associate',
  yearsOfExperience: '2 years',
  education: '12th, UP Board, 2019',
  workHistory: 'Warehouse Associate, ABC Logistics, 2022-2024',
  skills: 'Inventory management, Forklift operation',
});

describe('GeminiResumeParser', () => {
  it('sends the resume text as a single user turn and returns the parsed fields', async () => {
    let seenParams: unknown;
    const client = fakeClient(async (params) => {
      seenParams = params;
      return { text: FULL_JSON };
    });
    const parser = new GeminiResumeParser(client);

    const result = await parser.parseResume({
      resumeText: 'Asha Kumari, Warehouse Associate...',
    });

    expect(result).toEqual({
      fields: {
        fullName: 'Asha Kumari',
        phone: '9876543210',
        email: 'asha@example.com',
        city: 'Lucknow',
        headline: 'Warehouse Associate',
        yearsOfExperience: '2 years',
        education: '12th, UP Board, 2019',
        workHistory: 'Warehouse Associate, ABC Logistics, 2022-2024',
        skills: 'Inventory management, Forklift operation',
      },
      modelId: GEMINI_RESUME_MODEL_ID,
    });
    expect(seenParams).toMatchObject({
      model: GEMINI_RESUME_MODEL_ID,
      contents: [
        {
          role: 'user',
          parts: [{ text: expect.stringContaining('Asha Kumari') }],
        },
      ],
      config: { maxOutputTokens: 1200 },
    });
  });

  it('fills in an empty string for any field the model omits', async () => {
    const client = fakeClient(async () => ({
      text: JSON.stringify({ fullName: 'Ravi Singh' }),
    }));
    const parser = new GeminiResumeParser(client);

    const result = await parser.parseResume({ resumeText: 'Ravi Singh...' });

    expect(result.fields).toEqual({
      fullName: 'Ravi Singh',
      phone: '',
      email: '',
      city: '',
      headline: '',
      yearsOfExperience: '',
      education: '',
      workHistory: '',
      skills: '',
    });
  });

  it('strips a markdown code fence the model wraps its JSON in despite being asked not to', async () => {
    const client = fakeClient(async () => ({
      text: '```json\n' + FULL_JSON + '\n```',
    }));
    const parser = new GeminiResumeParser(client);

    const result = await parser.parseResume({ resumeText: 'x' });
    expect(result.fields.fullName).toBe('Asha Kumari');
  });

  it('throws when Gemini returns an empty response', async () => {
    const client = fakeClient(async () => ({ text: '   ' }));
    const parser = new GeminiResumeParser(client);

    await expect(
      parser.parseResume({ resumeText: 'x' }),
    ).rejects.toThrow('Gemini returned an empty resume extraction.');
  });

  it('throws when Gemini returns text that is not valid JSON', async () => {
    const client = fakeClient(async () => ({
      text: 'Sure, here is the candidate: Asha Kumari...',
    }));
    const parser = new GeminiResumeParser(client);

    await expect(parser.parseResume({ resumeText: 'x' })).rejects.toThrow(
      'Gemini did not return valid JSON for the resume extraction.',
    );
  });

  it('throws when Gemini returns valid JSON that is not an object', async () => {
    const client = fakeClient(async () => ({ text: '["Asha Kumari"]' }));
    const parser = new GeminiResumeParser(client);

    await expect(parser.parseResume({ resumeText: 'x' })).rejects.toThrow(
      'Gemini returned a non-object JSON payload for the resume extraction.',
    );
  });
});
