import { Inject, Injectable } from '@nestjs/common';
import { AppError } from '../common/app-error';
import { ResumeAiParseResult, ResumeAiProvider } from './resume-ai-provider';
import { RESUME_AI_PROVIDER } from './resume-ai-provider.token';

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

export interface ResumeParseRequestBody {
  resumeText: string;
  consentVersion: string;
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
    if (!body.consentVersion?.trim()) {
      throw AppError.consentRequired(
        'Accept the resume-parsing consent before uploading a resume.',
      );
    }

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

    try {
      const result = await this.provider.parseResume({ resumeText });
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
