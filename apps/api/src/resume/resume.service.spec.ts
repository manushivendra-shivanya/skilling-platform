import {
  ParseResumeParams,
  ResumeAiParseResult,
  ResumeAiProvider,
} from './resume-ai-provider';
import { ResumeService } from './resume.service';

function emptyResult(fullName: string): ResumeAiParseResult {
  return {
    fullName,
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
    modelId: 'fake-model',
  };
}

class FakeResumeParser implements ResumeAiProvider {
  readonly id = 'fake';
  calls: ParseResumeParams[] = [];
  result: ResumeAiParseResult = emptyResult('Asha Kumari');
  error: Error | null = null;

  async parseResume(params: ParseResumeParams) {
    this.calls.push(params);
    if (this.error) throw this.error;
    return this.result;
  }
}

const VALID_RESUME_TEXT =
  'Asha Kumari, Warehouse Associate. Two years experience at ABC Logistics.';

describe('ResumeService', () => {
  let provider: FakeResumeParser;
  let service: ResumeService;

  beforeEach(() => {
    provider = new FakeResumeParser();
    service = new ResumeService(provider);
  });

  it('rejects a request with no consent version, without calling the provider', async () => {
    await expect(
      service.parseResume('candidate-1', {
        resumeText: VALID_RESUME_TEXT,
        consentVersion: '',
      }),
    ).rejects.toMatchObject({ code: 'CONSENT_REQUIRED' });
    expect(provider.calls).toHaveLength(0);
  });

  it('rejects resume text under the minimum length, without calling the provider', async () => {
    await expect(
      service.parseResume('candidate-1', {
        resumeText: 'Too short',
        consentVersion: 'v1',
      }),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
    expect(provider.calls).toHaveLength(0);
  });

  it('rejects resume text over the maximum length, without calling the provider', async () => {
    await expect(
      service.parseResume('candidate-1', {
        resumeText: 'x'.repeat(20001),
        consentVersion: 'v1',
      }),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
    expect(provider.calls).toHaveLength(0);
  });

  it('trims resume text before sending it to the provider', async () => {
    await service.parseResume('candidate-1', {
      resumeText: `  ${VALID_RESUME_TEXT}  `,
      consentVersion: 'v1',
    });
    expect(provider.calls[0].resumeText).toBe(VALID_RESUME_TEXT);
  });

  it('returns the parsed extraction and provider metadata on success', async () => {
    const result = await service.parseResume('candidate-1', {
      resumeText: VALID_RESUME_TEXT,
      consentVersion: 'v1',
    });

    expect(result).toEqual({
      ...provider.result,
      requiresCandidateReview: false,
      provider: 'fake',
    });
  });

  it('flags requiresCandidateReview when fullName came back empty', async () => {
    provider.result = emptyResult('');

    const result = await service.parseResume('candidate-1', {
      resumeText: VALID_RESUME_TEXT,
      consentVersion: 'v1',
    });

    expect(result.requiresCandidateReview).toBe(true);
  });

  it('maps a provider failure to a generic service-unavailable error, not the raw provider error', async () => {
    provider.error = new Error('some internal Gemini detail');

    await expect(
      service.parseResume('candidate-1', {
        resumeText: VALID_RESUME_TEXT,
        consentVersion: 'v1',
      }),
    ).rejects.toMatchObject({
      code: 'RESUME_PARSE_UNAVAILABLE',
      message:
        'Resume parsing is temporarily unavailable. Please try again in a moment.',
    });
  });

  it('rate-limits a candidate after 10 parses in one day, independently per candidate', async () => {
    for (let i = 0; i < 10; i++) {
      await service.parseResume('candidate-1', {
        resumeText: VALID_RESUME_TEXT,
        consentVersion: 'v1',
      });
    }

    await expect(
      service.parseResume('candidate-1', {
        resumeText: VALID_RESUME_TEXT,
        consentVersion: 'v1',
      }),
    ).rejects.toMatchObject({ code: 'RATE_LIMITED' });

    // A different candidate is unaffected by candidate-1's limit.
    await expect(
      service.parseResume('candidate-2', {
        resumeText: VALID_RESUME_TEXT,
        consentVersion: 'v1',
      }),
    ).resolves.toBeDefined();
  });
});
