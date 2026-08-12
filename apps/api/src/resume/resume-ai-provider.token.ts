/**
 * Injection token for whichever ResumeAiProvider resume.module.ts
 * constructs -- ResumeService depends on this token, never on
 * GeminiResumeParser/UnconfiguredResumeParser directly. Mirrors
 * coach/coach-ai-provider.token.ts's convention (a plain string token,
 * not a Symbol).
 */
export const RESUME_AI_PROVIDER = 'RESUME_AI_PROVIDER';
