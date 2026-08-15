import { GoogleGenAI, Part } from '@google/genai';
import {
  ParsedCertificationEntry,
  ParsedEducationEntry,
  ParsedProjectEntry,
  ParsedWorkExperienceEntry,
  ParseResumeDocumentParams,
  ParseResumeParams,
  ResumeAiParseResult,
  ResumeAiProvider,
} from './resume-ai-provider';

// Same model as the coach's GeminiCoachProvider -- see that file's doc
// comment for why 2.5-flash was retired and 3.5-flash is current.
export const GEMINI_RESUME_MODEL_ID = 'gemini-3.5-flash';

/**
 * Deliberately NOT using Gemini's structured-JSON-output config (a
 * responseMimeType/responseSchema field on the request) -- this session
 * couldn't confirm that field's exact name against the current
 * @google/genai types without risking a silently-wrong parameter name on
 * a feature nobody would notice failing until a real resume came through.
 * Prompting for JSON in plain text and parsing it defensively here is
 * slower to fail-safe against than a schema-enforced response, but it's
 * a request shape already proven working (matches GeminiCoachProvider's
 * plain-text contents/config exactly) rather than a guessed one.
 *
 * `maxOutputTokens` is higher than the old flat-9-field contract needed
 * (1200) -- a full resume's worth of structured work-experience/education/
 * certification/project *arrays* is a materially larger response than
 * nine short strings.
 */
export class GeminiResumeParser implements ResumeAiProvider {
  readonly id = 'gemini';

  constructor(private readonly client: GoogleGenAI) {}

  async parseResume({
    resumeText,
  }: ParseResumeParams): Promise<ResumeAiParseResult> {
    return this.extract([{ text: buildPrompt(resumeText) }]);
  }

  /**
   * The uploaded file goes to the model as an `inlineData` part -- the
   * shape `Part.inlineData: { data (base64), mimeType }` declared by the
   * installed @google/genai typings, checked against them rather than
   * recalled, in keeping with this file's standing caution about guessed
   * request fields.
   *
   * Inline (rather than the Files API) because a resume is bounded to a
   * few megabytes by `ResumeService`, well inside the inline request
   * limit, and an upload-then-reference round trip would add a second
   * failure mode for no gain at this size.
   */
  async parseResumeDocument({
    contentBase64,
    mimeType,
  }: ParseResumeDocumentParams): Promise<ResumeAiParseResult> {
    return this.extract([
      { inlineData: { data: contentBase64, mimeType } },
      { text: buildPrompt(null) },
    ]);
  }

  private async extract(parts: Part[]): Promise<ResumeAiParseResult> {
    const response = await this.client.models.generateContent({
      model: GEMINI_RESUME_MODEL_ID,
      contents: [{ role: 'user', parts }],
      config: { maxOutputTokens: 4000 },
    });

    const text = response.text?.trim();
    if (!text) {
      throw new Error('Gemini returned an empty resume extraction.');
    }

    return {
      ...parseExtractionJson(text),
      modelId: GEMINI_RESUME_MODEL_ID,
    };
  }
}

/**
 * One prompt for both input routes. [resumeText] is null when the resume
 * arrives as an attached document instead of pasted text -- every
 * extraction and normalization rule above the source is identical either
 * way, and duplicating them into a second prompt would guarantee the two
 * drift apart.
 */
function buildPrompt(resumeText: string | null): string {
  const source =
    resumeText === null
      ? `The resume is the document attached to this message. Read all of it, including every page, and follow the rules above against its contents.`
      : `Resume text:
"""
${resumeText}
"""`;
  return `You extract and INTERPRET structured fields from a candidate's resume for a job-skilling platform serving warehouse, logistics, and similar operational roles in India.

Two different rules apply to different fields -- follow both exactly:
1. Literal fields (fullName, phone, email, city, headline, company, institution names, etc.): extract only what the resume actually states. Never invent or infer a value that isn't there.
2. Interpreted fields (degree, fieldOfStudy): NORMALIZE common abbreviations into their full, standard form and SPLIT the degree from its field of study. For example, "BTech CS" or "B.Tech. Computer Science" both become degree: "Bachelor of Technology", fieldOfStudy: "Computer Science". "B.Com" becomes degree: "Bachelor of Commerce", fieldOfStudy: "" (no field stated). "12th, CBSE" becomes degree: "12th (Higher Secondary)", fieldOfStudy: "", institution: "CBSE". Never invent a field of study that isn't implied by the abbreviation itself or explicitly stated.

Respond with ONLY a single JSON object, no markdown code fences, no commentary before or after it, matching this exact shape:

{
  "fullName": "the candidate's full name, or "" if not stated",
  "phone": "phone number as written, or """,
  "email": "email address as written, or """,
  "city": "current city, or "" if not stated",
  "headline": "their current or most recent job title/role, one line, or """,
  "yearsOfExperience": "a short phrase like '3 years' or 'Fresher' -- your best literal read of total experience, not a guess beyond what's stated or clearly computable from listed dates, or """,
  "skills": ["one array entry per distinct skill as stated in the resume -- do not comma-split a single stated phrase into multiple skills"],
  "education": [
    {
      "institution": "school/college/university name, or """,
      "degree": "normalized degree, e.g. 'Bachelor of Technology' -- see the interpretation rule above",
      "fieldOfStudy": "normalized field of study, e.g. 'Computer Science', or "" if none stated or implied",
      "startYear": 2019,
      "endYear": 2023,
      "grade": "grade/percentage/CGPA as stated, or """
    }
  ],
  "workExperience": [
    {
      "title": "job title as stated",
      "company": "employer name as stated",
      "location": "work location, or """,
      "startMonth": 6,
      "startYear": 2022,
      "endMonth": null,
      "endYear": null,
      "isCurrent": true,
      "description": "one or two sentences summarizing the role, in the candidate's own words from the resume, or """
    }
  ],
  "certifications": [
    {
      "name": "certification name as stated",
      "issuingOrganization": "issuing body, or """,
      "issueMonth": null,
      "issueYear": 2021,
      "expiryMonth": null,
      "expiryYear": null
    }
  ],
  "projects": [
    {
      "title": "project title as stated",
      "role": "the candidate's role on it, or """,
      "description": "one or two sentences, or """,
      "startMonth": null,
      "startYear": null,
      "endMonth": null,
      "endYear": null,
      "isOngoing": false,
      "url": "a project URL if one is stated, or """
    }
  ]
}

Rules for the array fields (education, workExperience, certifications, projects): include one entry per item the resume actually lists, most recent first. An empty array is correct when the resume genuinely lists nothing for that section -- do not invent an entry to avoid an empty array. Use JSON null (not a string) for any month/year that isn't stated. Only set isCurrent/isOngoing to true when the resume itself says "present", "current", "ongoing" or equivalent.

${source}`;
}

function parseExtractionJson(
  text: string,
): Omit<ResumeAiParseResult, 'modelId'> {
  const jsonText = stripMarkdownFence(text);
  let parsed: unknown;
  try {
    parsed = JSON.parse(jsonText);
  } catch {
    throw new Error(
      'Gemini did not return valid JSON for the resume extraction.',
    );
  }
  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    throw new Error(
      'Gemini returned a non-object JSON payload for the resume extraction.',
    );
  }

  const source = parsed as Record<string, unknown>;
  return {
    fullName: toStr(source.fullName),
    phone: toStr(source.phone),
    email: toStr(source.email),
    city: toStr(source.city),
    headline: toStr(source.headline),
    yearsOfExperience: toStr(source.yearsOfExperience),
    skills: toStrArray(source.skills),
    education: toEducationArray(source.education),
    workExperience: toWorkExperienceArray(source.workExperience),
    certifications: toCertificationArray(source.certifications),
    projects: toProjectArray(source.projects),
  };
}

// --- Defensive field coercion -----------------------------------------
// The model is asked for exact types (string/number/boolean/null), but
// nothing enforces that on the wire -- these helpers accept the asked-for
// shape and fail soft (empty string/null/false/dropped entry) on anything
// else, rather than throwing and discarding an otherwise-usable
// extraction over one malformed field.

function toStr(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function toNullableInt(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === 'string' && value.trim() !== '') {
    const parsed = Number.parseInt(value.trim(), 10);
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

function toBool(value: unknown): boolean {
  return value === true;
}

function toStrArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((entry): entry is string => typeof entry === 'string')
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
}

function toEducationArray(value: unknown): ParsedEducationEntry[] {
  if (!Array.isArray(value)) return [];
  const entries: ParsedEducationEntry[] = [];
  for (const raw of value) {
    if (typeof raw !== 'object' || raw === null) continue;
    const row = raw as Record<string, unknown>;
    const institution = toStr(row.institution);
    const degree = toStr(row.degree);
    // Drop an entry with neither -- nothing useful to keep.
    if (!institution && !degree) continue;
    entries.push({
      institution,
      degree,
      fieldOfStudy: toStr(row.fieldOfStudy),
      startYear: toNullableInt(row.startYear),
      endYear: toNullableInt(row.endYear),
      grade: toStr(row.grade),
    });
  }
  return entries;
}

function toWorkExperienceArray(
  value: unknown,
): ParsedWorkExperienceEntry[] {
  if (!Array.isArray(value)) return [];
  const entries: ParsedWorkExperienceEntry[] = [];
  for (const raw of value) {
    if (typeof raw !== 'object' || raw === null) continue;
    const row = raw as Record<string, unknown>;
    const title = toStr(row.title);
    const company = toStr(row.company);
    if (!title && !company) continue;
    entries.push({
      title,
      company,
      location: toStr(row.location),
      startMonth: toNullableInt(row.startMonth),
      startYear: toNullableInt(row.startYear),
      endMonth: toNullableInt(row.endMonth),
      endYear: toNullableInt(row.endYear),
      isCurrent: toBool(row.isCurrent),
      description: toStr(row.description),
    });
  }
  return entries;
}

function toCertificationArray(
  value: unknown,
): ParsedCertificationEntry[] {
  if (!Array.isArray(value)) return [];
  const entries: ParsedCertificationEntry[] = [];
  for (const raw of value) {
    if (typeof raw !== 'object' || raw === null) continue;
    const row = raw as Record<string, unknown>;
    const name = toStr(row.name);
    if (!name) continue;
    entries.push({
      name,
      issuingOrganization: toStr(row.issuingOrganization),
      issueMonth: toNullableInt(row.issueMonth),
      issueYear: toNullableInt(row.issueYear),
      expiryMonth: toNullableInt(row.expiryMonth),
      expiryYear: toNullableInt(row.expiryYear),
    });
  }
  return entries;
}

function toProjectArray(value: unknown): ParsedProjectEntry[] {
  if (!Array.isArray(value)) return [];
  const entries: ParsedProjectEntry[] = [];
  for (const raw of value) {
    if (typeof raw !== 'object' || raw === null) continue;
    const row = raw as Record<string, unknown>;
    const title = toStr(row.title);
    if (!title) continue;
    entries.push({
      title,
      role: toStr(row.role),
      description: toStr(row.description),
      startMonth: toNullableInt(row.startMonth),
      startYear: toNullableInt(row.startYear),
      endMonth: toNullableInt(row.endMonth),
      endYear: toNullableInt(row.endYear),
      isOngoing: toBool(row.isOngoing),
      url: toStr(row.url),
    });
  }
  return entries;
}

// Cheap defensive parsing, not a full markdown parser -- the prompt asks
// the model not to wrap its answer in ```json fences, but models don't
// always comply, and stripping a fence if present costs nothing when it
// isn't.
function stripMarkdownFence(text: string): string {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  return (fenced ? fenced[1] : text).trim();
}
