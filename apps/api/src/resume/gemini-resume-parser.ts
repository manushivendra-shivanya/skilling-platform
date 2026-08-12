import { GoogleGenAI } from '@google/genai';
import {
  ParseResumeParams,
  ResumeAiParseResult,
  ResumeAiProvider,
} from './resume-ai-provider';

// Same model as the coach's GeminiCoachProvider -- see that file's doc
// comment for why 2.5-flash was retired and 3.5-flash is current.
export const GEMINI_RESUME_MODEL_ID = 'gemini-3.5-flash';

// Every key this parser will always return (possibly empty) -- fixed and
// flat so the response maps directly onto the mobile
// `ResumeParseResult.fields` contract (`Map<String, String>`). Multi-item
// fields (education, work history, skills) are one readable summary
// string each, not arrays -- see the prompt below for the exact format
// asked of the model.
const EXTRACTION_FIELDS = [
  'fullName',
  'phone',
  'email',
  'city',
  'headline',
  'yearsOfExperience',
  'education',
  'workHistory',
  'skills',
] as const;

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
 */
export class GeminiResumeParser implements ResumeAiProvider {
  readonly id = 'gemini';

  constructor(private readonly client: GoogleGenAI) {}

  async parseResume({
    resumeText,
  }: ParseResumeParams): Promise<ResumeAiParseResult> {
    const response = await this.client.models.generateContent({
      model: GEMINI_RESUME_MODEL_ID,
      contents: [{ role: 'user', parts: [{ text: buildPrompt(resumeText) }] }],
      config: { maxOutputTokens: 1200 },
    });

    const text = response.text?.trim();
    if (!text) {
      throw new Error('Gemini returned an empty resume extraction.');
    }

    return { fields: parseExtractionJson(text), modelId: GEMINI_RESUME_MODEL_ID };
  }
}

function buildPrompt(resumeText: string): string {
  return `You extract structured fields from a candidate's resume for a job-skilling platform serving warehouse, logistics, and similar operational roles in India. Be literal -- extract only what the resume actually states, never invent or infer a value that isn't there.

Respond with ONLY a single JSON object, no markdown code fences, no commentary before or after it. Every key below must be present; use an empty string "" for anything not found in the resume text. Do not add any keys beyond these:

{
  "fullName": "the candidate's full name",
  "phone": "phone number as written",
  "email": "email address as written",
  "city": "current city, if stated",
  "headline": "their current or most recent job title/role, one line",
  "yearsOfExperience": "a short phrase like '3 years' or 'Fresher' -- your best literal read of total experience, not a guess beyond what's stated or clearly computable from listed dates",
  "education": "one line per qualification, most recent first, separated by ' | ' -- e.g. 'B.Com, Delhi University, 2022 | 12th, CBSE, 2019'",
  "workHistory": "one line per role, most recent first, separated by ' | ' -- e.g. 'Warehouse Associate, ABC Logistics, 2022-2024 | Store Helper, XYZ Retail, 2020-2022'",
  "skills": "a comma-separated list of skills as stated in the resume"
}

Resume text:
"""
${resumeText}
"""`;
}

function parseExtractionJson(text: string): Record<string, string> {
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
  const fields: Record<string, string> = {};
  for (const key of EXTRACTION_FIELDS) {
    const value = source[key];
    fields[key] = typeof value === 'string' ? value.trim() : '';
  }
  return fields;
}

// Cheap defensive parsing, not a full markdown parser -- the prompt asks
// the model not to wrap its answer in ```json fences, but models don't
// always comply, and stripping a fence if present costs nothing when it
// isn't.
function stripMarkdownFence(text: string): string {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  return (fenced ? fenced[1] : text).trim();
}
