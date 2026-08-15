import { Inject, Injectable } from '@nestjs/common';
import { AppError } from '../common/app-error';
import { ResumeAiParseResult, ResumeAiProvider } from './resume-ai-provider';
import { RESUME_AI_PROVIDER } from './resume-ai-provider.token';
import {
  extractDocxText,
  ResumeDocumentKind,
  sniffResumeDocumentKind,
} from './resume-document';

// A near-empty paste would produce a fabricated-looking extraction (the
// model filling in blanks with plausible-sounding guesses) rather than an
// honest "not enough to work with" -- reject below this length instead.
const MIN_RESUME_TEXT_LENGTH = 40;
// Generous for a few pages of plain resume text, bounded against
// runaway token cost / an accidental (or malicious) huge paste.
const MAX_RESUME_TEXT_LENGTH = 20000;
// Parsing is heavier and rarer than a single coach message -- 10/day is
// already generous for "re-parse after editing your resume."  Same
// in-memory, resets-on-restart posture as CoachService's rate limit; see
// that file's doc comment for why that trade-off is accepted for v1.
const RATE_LIMIT_PER_DAY = 10;
// A resume is a handful of pages. This is generous for a scanned PDF and
// still far inside what an inline model request accepts -- the ceiling
// exists so an accidental 40MB upload fails fast at the edge instead of
// after being base64-decoded and shipped to the model.
const MAX_RESUME_FILE_BYTES = 5 * 1024 * 1024;

export interface ResumeParseRequestBody {
  resumeText: string;
  consentVersion: string;
}

export interface ResumeDocumentParseRequestBody {
  /** Raw file bytes, base64-encoded. */
  contentBase64: string;
  consentVersion: string;
  /**
   * What the client called the file. Recorded for nothing but error
   * wording -- the format is decided by sniffing the bytes (see
   * `sniffResumeDocumentKind`), never by this or by a declared mime type.
   */
  fileName?: string;
}

export interface ResumeParseResponse extends ResumeAiParseResult {
  requiresCandidateReview: boolean;
  provider: string;
}

@Injectable()
export class ResumeService {
  private readonly dailyParseCounts = new Map<
    string,
    { day: string; count: number }
  >();

  constructor(
    @Inject(RESUME_AI_PROVIDER) private readonly provider: ResumeAiProvider,
  ) {}

  async parseResume(
    candidateId: string,
    body: ResumeParseRequestBody,
  ): Promise<ResumeParseResponse> {
    this.requireConsent(body.consentVersion);

    const resumeText = body.resumeText?.trim() ?? '';
    if (resumeText.length < MIN_RESUME_TEXT_LENGTH) {
      throw AppError.validation(
        `Paste more of your resume text -- at least ${MIN_RESUME_TEXT_LENGTH} characters.`,
      );
    }
    if (resumeText.length > MAX_RESUME_TEXT_LENGTH) {
      throw AppError.validation(
        `Resume text is too long -- keep it under ${MAX_RESUME_TEXT_LENGTH} characters.`,
      );
    }

    this.enforceRateLimit(candidateId);

    return this.extract(() => this.provider.parseResume({ resumeText }));
  }

  /**
   * The upload route: the candidate picks the resume file they already
   * have instead of pasting its text.
   *
   * The two supported formats take deliberately different paths. A PDF
   * goes to the model as the original file -- resumes lean on two-column
   * layouts and tables, and extracting text from those first interleaves
   * the columns into something no model can read back correctly. A .docx
   * has no such native route, so its text is extracted here and rejoins
   * the ordinary pasted-text pipeline, prompt and all.
   *
   * The format is decided by the file's own magic number, never by the
   * mime type or extension the client claims -- see
   * `sniffResumeDocumentKind` for why both are untrustworthy in ordinary
   * use, before considering a hostile one.
   */
  async parseResumeDocument(
    candidateId: string,
    body: ResumeDocumentParseRequestBody,
  ): Promise<ResumeParseResponse> {
    this.requireConsent(body.consentVersion);

    const bytes = this.decodeUpload(body.contentBase64);
    const kind = sniffResumeDocumentKind(bytes);
    this.rejectUnreadableKind(kind);

    this.enforceRateLimit(candidateId);

    if (kind === 'pdf') {
      return this.extract(() =>
        this.provider.parseResumeDocument({
          // Re-encoded from the decoded bytes rather than forwarding the
          // client's string, so exactly what was size-checked and
          // sniffed is what reaches the model, in canonical base64.
          contentBase64: bytes.toString('base64'),
          mimeType: 'application/pdf',
        }),
      );
    }

    let resumeText: string;
    try {
      resumeText = await extractDocxText(bytes);
    } catch {
      throw AppError.serviceUnavailable(
        'RESUME_PARSE_UNAVAILABLE',
        'That Word file could not be read. Please try again, or save it as a PDF and upload that instead.',
      );
    }
    if (resumeText.length < MIN_RESUME_TEXT_LENGTH) {
      // Overwhelmingly this means a document whose content is images --
      // a scan pasted into Word. Saying so points at the fix, where a
      // bare "not enough text" would leave the candidate re-uploading
      // the same file.
      throw AppError.validation(
        'That Word file has almost no text in it -- if the resume is a scan or an image, save it as a PDF and upload that instead.',
      );
    }
    if (resumeText.length > MAX_RESUME_TEXT_LENGTH) {
      throw AppError.validation(
        `That file has more text than can be processed at once -- keep the resume under ${MAX_RESUME_TEXT_LENGTH} characters.`,
      );
    }

    return this.extract(() => this.provider.parseResume({ resumeText }));
  }

  private requireConsent(consentVersion: string | undefined): void {
    if (!consentVersion?.trim()) {
      throw AppError.consentRequired(
        'Accept the resume-parsing consent before uploading a resume.',
      );
    }
  }

  private decodeUpload(contentBase64: string | undefined): Buffer {
    const encoded = contentBase64?.trim() ?? '';
    if (!encoded) {
      throw AppError.validation('Choose a resume file to upload.');
    }
    // Node's base64 decoder skips anything it doesn't recognise rather
    // than throwing, so a corrupted upload arrives here as plausible
    // bytes. Nothing downstream trusts them on that basis: the magic-
    // number sniff is what decides whether this is really a resume.
    const bytes = Buffer.from(encoded, 'base64');
    if (bytes.length === 0) {
      throw AppError.validation(
        'That file could not be read. Please choose it again.',
      );
    }
    if (bytes.length > MAX_RESUME_FILE_BYTES) {
      const limitMb = Math.floor(MAX_RESUME_FILE_BYTES / (1024 * 1024));
      throw AppError.validation(
        `That file is too large -- upload a resume under ${limitMb} MB.`,
      );
    }
    return bytes;
  }

  private rejectUnreadableKind(kind: ResumeDocumentKind): void {
    if (kind === 'pdf' || kind === 'docx') return;
    if (kind === 'doc') {
      throw AppError.validation(
        'Older Word (.doc) files cannot be read. Open it in Word, save it as a PDF or .docx, and upload that instead.',
      );
    }
    throw AppError.validation(
      'That file is not a resume this app can read. Upload a PDF or a Word (.docx) file.',
    );
  }

  /**
   * Runs one provider call and shapes the response. Every provider
   * failure -- a model outage, a malformed extraction, an unconfigured
   * API key -- deliberately collapses into one 503 so that a missing
   * `GEMINI_API_KEY` is not distinguishable from the outside.
   */
  private async extract(
    call: () => Promise<ResumeAiParseResult>,
  ): Promise<ResumeParseResponse> {
    try {
      const result = await call();
      // Deterministic completeness check, not the model self-reporting a
      // confidence score -- an LLM's own confidence claim isn't something
      // this service can verify, so it isn't trusted as one. fullName is
      // the one field every other extracted field is presented alongside
      // in the mobile review UI, so its absence means "look at this
      // before trusting anything else here."
      const requiresCandidateReview = !result.fullName.trim();
      return {
        ...result,
        requiresCandidateReview,
        provider: this.provider.id,
      };
    } catch {
      throw AppError.serviceUnavailable(
        'RESUME_PARSE_UNAVAILABLE',
        'Resume parsing is temporarily unavailable. Please try again in a moment.',
      );
    }
  }

  private enforceRateLimit(candidateId: string): void {
    const today = new Date().toISOString().slice(0, 10);
    const existing = this.dailyParseCounts.get(candidateId);
    if (!existing || existing.day !== today) {
      this.dailyParseCounts.set(candidateId, { day: today, count: 1 });
      return;
    }
    if (existing.count >= RATE_LIMIT_PER_DAY) {
      throw AppError.rateLimited(
        "You have reached today's resume-parsing limit. Please try again tomorrow.",
      );
    }
    existing.count += 1;
  }
}
