export interface ParseResumeParams {
  resumeText: string;
}

/**
 * One qualification. [degree] and [fieldOfStudy] are deliberately separate
 * fields, not one free-text string -- this is the "intelligence" layer:
 * an abbreviation like "BTech CS" on the resume should come back here as
 * `degree: "Bachelor of Technology"` / `fieldOfStudy: "Computer Science"`,
 * not kept verbatim. Mirrors `candidate_education`
 * (supabase/migrations/20260814140000_candidate_detailed_profile.sql) and
 * the mobile `EducationEntry` domain model field-for-field.
 */
export interface ParsedEducationEntry {
  institution: string;
  degree: string;
  fieldOfStudy: string;
  startYear: number | null;
  endYear: number | null;
  grade: string;
}

/** Mirrors `candidate_work_experience` / the mobile `WorkExperienceEntry`. */
export interface ParsedWorkExperienceEntry {
  title: string;
  company: string;
  location: string;
  startMonth: number | null;
  startYear: number | null;
  endMonth: number | null;
  endYear: number | null;
  isCurrent: boolean;
  description: string;
}

/**
 * Mirrors `candidate_external_certifications` / the mobile
 * `ExternalCertificationEntry` -- a certification the candidate already
 * held before joining, not one of this platform's own in-app exams (see
 * that table's own migration comment for why the two are never conflated).
 */
export interface ParsedCertificationEntry {
  name: string;
  issuingOrganization: string;
  issueMonth: number | null;
  issueYear: number | null;
  expiryMonth: number | null;
  expiryYear: number | null;
}

/** Mirrors `candidate_projects` / the mobile `ProjectEntry`. */
export interface ParsedProjectEntry {
  title: string;
  role: string;
  description: string;
  startMonth: number | null;
  startYear: number | null;
  endMonth: number | null;
  endYear: number | null;
  isOngoing: boolean;
  url: string;
}

/**
 * A structured extraction, not a flat set of strings: [education],
 * [workExperience], [certifications] and [projects] are each a real array
 * of entries (mirroring the four `candidate_*` tables from
 * supabase/migrations/20260814140000_candidate_detailed_profile.sql), and
 * [skills] is a real string array, not one comma-joined line. This is what
 * lets the mobile client apply an extraction directly into
 * `DetailedCandidateProfile`'s repository calls (one upsert per entry)
 * instead of re-parsing a flattened summary string first.
 */
export interface ResumeAiParseResult {
  fullName: string;
  phone: string;
  email: string;
  city: string;
  headline: string;
  yearsOfExperience: string;
  skills: string[];
  education: ParsedEducationEntry[];
  workExperience: ParsedWorkExperienceEntry[];
  certifications: ParsedCertificationEntry[];
  projects: ParsedProjectEntry[];
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
