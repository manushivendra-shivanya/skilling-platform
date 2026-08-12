export interface ParseResumeParams {
  resumeText: string;
}

export interface ResumeAiParseResult {
  /**
   * A flat set of extracted fields -- deliberately not a richer nested
   * shape (no arrays/objects) so this maps directly onto the mobile
   * `ResumeParseResult.fields` contract
   * (candidate-mobile/lib/features/resume/domain/resume_parsing_repository.dart),
   * which is `Map<String, String>`. Multi-item fields (education, work
   * history, skills) are flattened into single readable summary strings
   * by the provider, not left as arrays for the caller to format.
   */
  fields: Record<string, string>;
  modelId: string;
}

/**
 * Mirrors CoachAiProvider's shape (coach/coach-ai-provider.ts) on purpose
 * -- same "provider behind an interface, injected client for testability,
 * unconfigured fallback" pattern, just for resume extraction instead of
 * chat. Only one real implementation exists today (Gemini); the interface
 * still exists (rather than calling GoogleGenAI directly from the
 * service) so a fallback provider can be added the same way
 * AnthropicCoachProvider was for Coach, without changing ResumeService.
 */
export interface ResumeAiProvider {
  readonly id: string;
  parseResume(params: ParseResumeParams): Promise<ResumeAiParseResult>;
}
