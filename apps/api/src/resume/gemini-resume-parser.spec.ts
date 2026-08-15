import { GoogleGenAI } from '@google/genai';
import {
  GEMINI_RESUME_MODEL_ID,
  GeminiResumeParser,
  RESUME_MAX_OUTPUT_TOKENS,
  ResumeTooLongError,
} from './gemini-resume-parser';

/**
 * Same fake-client posture as coach/gemini-coach-provider.spec.ts -- a
 * minimal fake of the one method this parser actually calls.
 */
function fakeClient(
  generateContent: (params: unknown) => Promise<{
    text: string | undefined;
    candidates?: { finishReason?: string }[];
  }>,
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
  skills: ['Inventory management', 'Forklift operation'],
  education: [
    {
      institution: 'Delhi University',
      degree: 'Bachelor of Technology',
      fieldOfStudy: 'Computer Science',
      startYear: 2019,
      endYear: 2023,
      grade: '7.8 CGPA',
    },
  ],
  workExperience: [
    {
      title: 'Warehouse Associate',
      company: 'ABC Logistics',
      location: 'Lucknow',
      startMonth: 6,
      startYear: 2022,
      endMonth: null,
      endYear: null,
      isCurrent: true,
      description: 'Receiving and put-away.',
    },
  ],
  certifications: [
    {
      name: 'Forklift Operator License',
      issuingOrganization: 'State Transport Authority',
      issueMonth: null,
      issueYear: 2021,
      expiryMonth: null,
      expiryYear: null,
    },
  ],
  projects: [],
});

describe('GeminiResumeParser', () => {
  it('sends the resume text as a single user turn and returns the structured extraction', async () => {
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
      fullName: 'Asha Kumari',
      phone: '9876543210',
      email: 'asha@example.com',
      city: 'Lucknow',
      headline: 'Warehouse Associate',
      yearsOfExperience: '2 years',
      skills: ['Inventory management', 'Forklift operation'],
      education: [
        {
          institution: 'Delhi University',
          degree: 'Bachelor of Technology',
          fieldOfStudy: 'Computer Science',
          startYear: 2019,
          endYear: 2023,
          grade: '7.8 CGPA',
        },
      ],
      workExperience: [
        {
          title: 'Warehouse Associate',
          company: 'ABC Logistics',
          location: 'Lucknow',
          startMonth: 6,
          startYear: 2022,
          endMonth: null,
          endYear: null,
          isCurrent: true,
          description: 'Receiving and put-away.',
        },
      ],
      certifications: [
        {
          name: 'Forklift Operator License',
          issuingOrganization: 'State Transport Authority',
          issueMonth: null,
          issueYear: 2021,
          expiryMonth: null,
          expiryYear: null,
        },
      ],
      projects: [],
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
      config: { maxOutputTokens: RESUME_MAX_OUTPUT_TOKENS },
    });
  });

  it('sends an uploaded document as an inlineData part alongside the same prompt', async () => {
    let seenParams: unknown;
    const client = fakeClient(async (params) => {
      seenParams = params;
      return { text: FULL_JSON };
    });
    const parser = new GeminiResumeParser(client);

    const result = await parser.parseResumeDocument({
      contentBase64: 'JVBERi0xLjc=',
      mimeType: 'application/pdf',
    });

    expect(result.fullName).toBe('Asha Kumari');
    expect(seenParams).toMatchObject({
      model: GEMINI_RESUME_MODEL_ID,
      contents: [
        {
          role: 'user',
          parts: [
            {
              inlineData: {
                data: 'JVBERi0xLjc=',
                mimeType: 'application/pdf',
              },
            },
            // Same extraction and normalization rules as the pasted-text
            // prompt -- one prompt builder serves both routes, so the two
            // cannot drift apart.
            { text: expect.stringContaining('normalized degree') },
          ],
        },
      ],
      config: { maxOutputTokens: RESUME_MAX_OUTPUT_TOKENS },
    });
  });

  it('does not leave a pasted-text placeholder in the document prompt', async () => {
    let seenParams: unknown;
    const client = fakeClient(async (params) => {
      seenParams = params;
      return { text: FULL_JSON };
    });
    const parser = new GeminiResumeParser(client);

    await parser.parseResumeDocument({
      contentBase64: 'JVBERi0xLjc=',
      mimeType: 'application/pdf',
    });

    const prompt = (
      seenParams as { contents: { parts: { text?: string }[] }[] }
    ).contents[0].parts[1].text;
    expect(prompt).toContain('document attached to this message');
    expect(prompt).not.toContain('Resume text:');
  });

  it('interprets an abbreviated degree the model already normalized into degree/fieldOfStudy', async () => {
    // The prompt asks the model to do the interpretation (e.g. "BTech CS"
    // -> "Bachelor of Technology" / "Computer Science") -- this test
    // guards the parsing side: that a normalized {degree, fieldOfStudy}
    // pair round-trips untouched rather than being re-flattened.
    const client = fakeClient(async () => ({
      text: JSON.stringify({
        fullName: 'Ravi Singh',
        education: [
          {
            institution: 'Anna University',
            degree: 'Bachelor of Technology',
            fieldOfStudy: 'Computer Science',
            startYear: null,
            endYear: null,
            grade: '',
          },
        ],
      }),
    }));
    const parser = new GeminiResumeParser(client);

    const result = await parser.parseResume({ resumeText: 'Ravi Singh...' });

    expect(result.education).toEqual([
      {
        institution: 'Anna University',
        degree: 'Bachelor of Technology',
        fieldOfStudy: 'Computer Science',
        startYear: null,
        endYear: null,
        grade: '',
      },
    ]);
  });

  it('fills in empty/empty-array defaults for any field the model omits', async () => {
    const client = fakeClient(async () => ({
      text: JSON.stringify({ fullName: 'Ravi Singh' }),
    }));
    const parser = new GeminiResumeParser(client);

    const result = await parser.parseResume({ resumeText: 'Ravi Singh...' });

    expect(result).toEqual({
      fullName: 'Ravi Singh',
      phone: '',
      email: '',
      city: '',
      headline: '',
      yearsOfExperience: '',
      skills: [],
      education: [],
      workExperience: [],
      certifications: [],
      projects: [],
      modelId: GEMINI_RESUME_MODEL_ID,
    });
  });

  it('drops a malformed array entry instead of throwing away the whole extraction', async () => {
    const client = fakeClient(async () => ({
      text: JSON.stringify({
        fullName: 'Ravi Singh',
        workExperience: [
          { title: 'Warehouse Associate', company: 'ABC Logistics' },
          'not an object',
          { title: '', company: '' },
          null,
        ],
      }),
    }));
    const parser = new GeminiResumeParser(client);

    const result = await parser.parseResume({ resumeText: 'x' });

    expect(result.workExperience).toEqual([
      expect.objectContaining({
        title: 'Warehouse Associate',
        company: 'ABC Logistics',
      }),
    ]);
  });

  it('coerces a numeric field sent back as a string instead of throwing', async () => {
    const client = fakeClient(async () => ({
      text: JSON.stringify({
        fullName: 'Ravi Singh',
        education: [
          {
            institution: 'Delhi University',
            degree: '',
            fieldOfStudy: '',
            startYear: '2019',
            endYear: '2023',
            grade: '',
          },
        ],
      }),
    }));
    const parser = new GeminiResumeParser(client);

    const result = await parser.parseResume({ resumeText: 'x' });

    expect(result.education[0].startYear).toBe(2019);
    expect(result.education[0].endYear).toBe(2023);
  });

  it('strips a markdown code fence the model wraps its JSON in despite being asked not to', async () => {
    const client = fakeClient(async () => ({
      text: '```json\n' + FULL_JSON + '\n```',
    }));
    const parser = new GeminiResumeParser(client);

    const result = await parser.parseResume({ resumeText: 'x' });
    expect(result.fullName).toBe('Asha Kumari');
  });

  it('reports a truncated extraction as too-long rather than as invalid JSON', async () => {
    // A response cut off at the token ceiling still carries text -- just
    // a JSON document that stops mid-object. Without the finishReason
    // check this surfaced as "did not return valid JSON", which points
    // at the model instead of at the resume's length.
    const client = fakeClient(async () => ({
      text: '{"fullName": "Asha Kumari", "workExperience": [{"title": "Warehou',
      candidates: [{ finishReason: 'MAX_TOKENS' }],
    }));
    const parser = new GeminiResumeParser(client);

    await expect(
      parser.parseResume({ resumeText: 'a very long resume' }),
    ).rejects.toBeInstanceOf(ResumeTooLongError);
  });

  it('does not mistake a normally-finished response for a truncated one', async () => {
    const client = fakeClient(async () => ({
      text: FULL_JSON,
      candidates: [{ finishReason: 'STOP' }],
    }));
    const parser = new GeminiResumeParser(client);

    await expect(
      parser.parseResume({ resumeText: 'Asha Kumari...' }),
    ).resolves.toMatchObject({ fullName: 'Asha Kumari' });
  });

  it('names the finish reason when Gemini returns no text at all', async () => {
    const client = fakeClient(async () => ({
      text: undefined,
      candidates: [{ finishReason: 'SAFETY' }],
    }));
    const parser = new GeminiResumeParser(client);

    // Not swallowed as a bare "empty extraction" -- the reason is what
    // makes the server log worth reading.
    await expect(
      parser.parseResume({ resumeText: 'Asha Kumari...' }),
    ).rejects.toThrow('SAFETY');
  });

  it('throws when Gemini returns an empty response', async () => {
    const client = fakeClient(async () => ({ text: '   ' }));
    const parser = new GeminiResumeParser(client);

    await expect(
      parser.parseResume({ resumeText: 'x' }),
    ).rejects.toThrow('Gemini returned an empty resume extraction');
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
