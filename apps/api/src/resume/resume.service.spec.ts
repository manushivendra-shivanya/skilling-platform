import {
  ParseResumeDocumentParams,
  ParseResumeParams,
  ResumeAiParseResult,
  ResumeAiProvider,
} from './resume-ai-provider';
import { ResumeService } from './resume.service';
import { makeDocx } from './testing/make-docx';

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
  documentCalls: ParseResumeDocumentParams[] = [];
  result: ResumeAiParseResult = emptyResult('Asha Kumari');
  error: Error | null = null;

  async parseResume(params: ParseResumeParams) {
    this.calls.push(params);
    if (this.error) throw this.error;
    return this.result;
  }

  async parseResumeDocument(params: ParseResumeDocumentParams) {
    this.documentCalls.push(params);
    if (this.error) throw this.error;
    return this.result;
  }
}

const VALID_RESUME_TEXT =
  'Asha Kumari, Warehouse Associate. Two years experience at ABC Logistics.';

function base64(bytes: Buffer): string {
  return bytes.toString('base64');
}

/** Enough of a PDF for the magic-number sniff; the model is faked. */
function fakePdf(): Buffer {
  return Buffer.from(`%PDF-1.7\n${VALID_RESUME_TEXT}\n%%EOF`, 'ascii');
}

function resumeDocx(): Buffer {
  return makeDocx([
    'Asha Kumari',
    'Warehouse Associate at ABC Logistics, two years experience.',
    'Forklift certified.',
  ]);
}

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

  describe('parseResumeDocument', () => {
    it('sends a PDF to the model as the original file, not as extracted text', async () => {
      const pdf = fakePdf();

      const result = await service.parseResumeDocument('candidate-1', {
        contentBase64: base64(pdf),
        consentVersion: 'v1',
        fileName: 'asha-resume.pdf',
      });

      expect(provider.documentCalls).toHaveLength(1);
      expect(provider.documentCalls[0].mimeType).toBe('application/pdf');
      expect(
        Buffer.from(provider.documentCalls[0].contentBase64, 'base64'),
      ).toEqual(pdf);
      // The text path is deliberately untouched for a PDF.
      expect(provider.calls).toHaveLength(0);
      expect(result.provider).toBe('fake');
      expect(result.requiresCandidateReview).toBe(false);
    });

    it('extracts a .docx to text and runs it through the ordinary text path', async () => {
      await service.parseResumeDocument('candidate-1', {
        contentBase64: base64(resumeDocx()),
        consentVersion: 'v1',
        fileName: 'asha-resume.docx',
      });

      expect(provider.documentCalls).toHaveLength(0);
      expect(provider.calls).toHaveLength(1);
      expect(provider.calls[0].resumeText).toContain('Asha Kumari');
      expect(provider.calls[0].resumeText).toContain('Forklift certified.');
    });

    it('decides the format from the bytes, not from the file name', async () => {
      // A PDF a picker labelled as a Word file still parses as a PDF --
      // and, more importantly, the reverse cannot smuggle arbitrary
      // bytes to the model as one.
      await service.parseResumeDocument('candidate-1', {
        contentBase64: base64(fakePdf()),
        consentVersion: 'v1',
        fileName: 'resume.docx',
      });

      expect(provider.documentCalls).toHaveLength(1);
      expect(provider.documentCalls[0].mimeType).toBe('application/pdf');
    });

    it('rejects a request with no consent version, without calling the provider', async () => {
      await expect(
        service.parseResumeDocument('candidate-1', {
          contentBase64: base64(fakePdf()),
          consentVersion: '',
        }),
      ).rejects.toMatchObject({ code: 'CONSENT_REQUIRED' });
      expect(provider.documentCalls).toHaveLength(0);
    });

    it('tells a candidate who uploaded a legacy .doc what to do instead', async () => {
      const ole2 = Buffer.concat([
        Buffer.from([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]),
        Buffer.alloc(128),
      ]);

      await expect(
        service.parseResumeDocument('candidate-1', {
          contentBase64: base64(ole2),
          consentVersion: 'v1',
          fileName: 'resume.doc',
        }),
      ).rejects.toMatchObject({
        code: 'VALIDATION_ERROR',
        message: expect.stringContaining('.docx'),
      });
      expect(provider.documentCalls).toHaveLength(0);
    });

    it('rejects a file that is not a resume format at all', async () => {
      const png = Buffer.concat([
        Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        Buffer.alloc(64),
      ]);

      await expect(
        service.parseResumeDocument('candidate-1', {
          contentBase64: base64(png),
          consentVersion: 'v1',
          fileName: 'photo.png',
        }),
      ).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
      expect(provider.documentCalls).toHaveLength(0);
    });

    it('rejects an empty upload', async () => {
      await expect(
        service.parseResumeDocument('candidate-1', {
          contentBase64: '',
          consentVersion: 'v1',
        }),
      ).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
    });

    it('rejects a file over the size ceiling before decoding it into a model request', async () => {
      const huge = Buffer.concat([
        Buffer.from('%PDF-1.7\n', 'ascii'),
        Buffer.alloc(6 * 1024 * 1024),
      ]);

      await expect(
        service.parseResumeDocument('candidate-1', {
          contentBase64: base64(huge),
          consentVersion: 'v1',
          fileName: 'scan.pdf',
        }),
      ).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
      expect(provider.documentCalls).toHaveLength(0);
    });

    it('says so plainly when a Word file turns out to hold no text', async () => {
      await expect(
        service.parseResumeDocument('candidate-1', {
          contentBase64: base64(makeDocx(['Resume'])),
          consentVersion: 'v1',
          fileName: 'scan.docx',
        }),
      ).rejects.toMatchObject({
        code: 'VALIDATION_ERROR',
        message: expect.stringContaining('scan'),
      });
      expect(provider.calls).toHaveLength(0);
    });

    it('maps a provider failure to the same generic service-unavailable error the text path gives', async () => {
      provider.error = new Error('some internal Gemini detail');

      await expect(
        service.parseResumeDocument('candidate-1', {
          contentBase64: base64(fakePdf()),
          consentVersion: 'v1',
        }),
      ).rejects.toMatchObject({
        code: 'RESUME_PARSE_UNAVAILABLE',
        message:
          'Resume parsing is temporarily unavailable. Please try again in a moment.',
      });
    });

    it('shares one daily quota with the paste-text path', async () => {
      // Uploading is not a way around the limit on pasting.
      for (let i = 0; i < 10; i++) {
        await service.parseResume('candidate-1', {
          resumeText: VALID_RESUME_TEXT,
          consentVersion: 'v1',
        });
      }

      await expect(
        service.parseResumeDocument('candidate-1', {
          contentBase64: base64(fakePdf()),
          consentVersion: 'v1',
        }),
      ).rejects.toMatchObject({ code: 'RATE_LIMITED' });
    });
  });
});
