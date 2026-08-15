import { ResumeAiParseResult, ResumeAiProvider } from './resume-ai-provider';

/**
 * Graceful degradation when GEMINI_API_KEY isn't configured -- same
 * posture as coach/unconfigured-coach-provider.ts, including taking no
 * parameters at all rather than an unused one (TypeScript's structural
 * typing allows an implementation with fewer parameters than the
 * interface declares). ResumeService maps this thrown error to the same
 * generic "temporarily unavailable" response it gives for a real
 * provider failure, so a missing key never leaks as a distinguishable
 * error to the client.
 */
export class UnconfiguredResumeParser implements ResumeAiProvider {
  readonly id = 'unconfigured';

  async parseResume(): Promise<ResumeAiParseResult> {
    throw new Error('Resume parsing is not configured.');
  }

  async parseResumeDocument(): Promise<ResumeAiParseResult> {
    throw new Error('Resume parsing is not configured.');
  }
}
