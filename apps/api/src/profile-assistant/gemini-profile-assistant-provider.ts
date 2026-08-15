import { GoogleGenAI } from '@google/genai';
import {
  ASSISTANT_WRITABLE_FIELDS,
  AssistantFieldUpdate,
  AssistantLanguageValue,
  AssistantReply,
  AssistantWritableField,
  ContinueConversationParams,
  LANGUAGE_PROFICIENCY_IDS,
  NOTICE_PERIOD_IDS,
  ProfileAssistantAiProvider,
} from './profile-assistant-ai-provider';

// Same model as GeminiCoachProvider/GeminiResumeParser -- see the coach
// provider's doc comment for why 3.5-flash is current.
export const GEMINI_PROFILE_ASSISTANT_MODEL_ID = 'gemini-3.5-flash';

/**
 * Plain-text JSON prompting with defensive parsing, not Gemini's
 * structured-output config -- exactly the reasoning documented on
 * `GeminiResumeParser`, and the same request shape proven working there.
 *
 * `maxOutputTokens` is modest: one question plus at most a couple of
 * field updates per turn is a far smaller response than a whole resume
 * extraction.
 */
export class GeminiProfileAssistantProvider
  implements ProfileAssistantAiProvider
{
  readonly id = 'gemini';

  constructor(private readonly client: GoogleGenAI) {}

  async continueConversation(
    params: ContinueConversationParams,
  ): Promise<AssistantReply> {
    const response = await this.client.models.generateContent({
      model: GEMINI_PROFILE_ASSISTANT_MODEL_ID,
      contents: [{ role: 'user', parts: [{ text: buildPrompt(params) }] }],
      config: { maxOutputTokens: 1200 },
    });

    const text = response.text?.trim();
    if (!text) {
      throw new Error('Gemini returned an empty profile-assistant reply.');
    }

    return {
      ...parseReplyJson(text),
      modelId: GEMINI_PROFILE_ASSISTANT_MODEL_ID,
    };
  }
}

function languageInstruction(languageTag: string): string {
  if (languageTag.startsWith('hi_Latn')) {
    return 'Reply in Hinglish -- conversational Hindi written in Latin script, the way people text in India. Do NOT use Devanagari.';
  }
  if (languageTag.startsWith('hi')) {
    return 'Reply in Hindi, using Devanagari script.';
  }
  return 'Reply in simple, clear English.';
}

export function buildPrompt({
  knownProfileDigest,
  remainingFields,
  history,
  languageTag,
}: ContinueConversationParams): string {
  const transcript = history
    .map(
      (turn) =>
        `${turn.role === 'assistant' ? 'ASSISTANT' : 'CANDIDATE'}: ${turn.text}`,
    )
    .join('\n');

  return `You are helping a blue-collar / entry-level logistics worker in India finish their job profile by having a short, friendly conversation. Many of them have never written a resume and may be answering on a phone in a noisy place.

${languageInstruction(languageTag)}

HOW TO TALK
- Ask about ONE thing at a time. Never ask two questions in one turn.
- Keep every message under 25 words. Short, warm, plain.
- Never use jargon like "CTC" without explaining it in plain words the first time.
- If an answer is vague ("thoda kam", "not sure"), ask one gentle follow-up rather than guessing.
- If the candidate clearly does not want to answer something, accept it and move to the next field. Never push twice.

WHAT IS ALREADY KNOWN (do not ask about these again):
${knownProfileDigest || '(nothing yet)'}

STILL MISSING, most important first:
${remainingFields.join(', ') || '(nothing)'}

CONVERSATION SO FAR:
${transcript || '(this is the first turn -- greet them briefly, then ask about the first missing field)'}

EXTRACTING ANSWERS
When the candidate's last message answers a field, record it in "updates". Rules:
- "headline", "summary", "totalExperience", "phone", "email" -> use "text".
- "expectedCtc" -> use "amount", ANNUAL rupees as a plain number. If they say a monthly figure, multiply by 12. "20 hazaar mahina" -> 240000. Never include commas or currency symbols.
- "skills", "preferredLocations" -> use "items", an array of short strings.
- "languages" -> use "languages", an array of {"language","proficiency"}. proficiency MUST be one of: ${LANGUAGE_PROFICIENCY_IDS.join(', ')}.
- "noticePeriod" -> use "id", exactly one of: ${NOTICE_PERIOD_IDS.join(', ')}. "turant"/"abhi" -> immediate. "15 din" -> fifteen_days. "ek mahina" -> one_month.
- Every update also needs "confirmation": a very short acknowledgement in the SAME language you are replying in, e.g. "15 days set kar diya".
- Only include a field in "updates" if the candidate actually answered it in their last message. Never invent or infer a value they did not say.
- If they declined to answer, do NOT add an update for it -- just move on.

Set "isComplete" to true only when nothing in the missing list is worth asking about anymore (all answered or all declined). When it is true, "text" should be a short, warm closing message instead of a question.

Reply with ONLY this JSON object and nothing else -- no markdown fence, no commentary:
{
  "text": "your next message to the candidate",
  "isComplete": false,
  "updates": [
    { "field": "noticePeriod", "id": "fifteen_days", "confirmation": "15 days set kar diya" }
  ]
}`;
}

/** Same fence-tolerance as the resume parser's own stripMarkdownFence. */
function stripMarkdownFence(raw: string): string {
  const fenced = raw.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/);
  return fenced ? fenced[1].trim() : raw;
}

function toStr(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function toStrArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => toStr(item))
    .filter((item) => item.length > 0);
}

function toLanguages(value: unknown): AssistantLanguageValue[] {
  if (!Array.isArray(value)) return [];
  const languages: AssistantLanguageValue[] = [];
  for (const raw of value) {
    if (typeof raw !== 'object' || raw === null) continue;
    const entry = raw as Record<string, unknown>;
    const language = toStr(entry.language);
    const proficiency = toStr(entry.proficiency);
    if (!language) continue;
    languages.push({
      language,
      // An unrecognised proficiency degrades to the most conservative
      // level rather than dropping the language entirely -- knowing the
      // candidate speaks Hindi at all is worth more than the exact band.
      proficiency: (
        LANGUAGE_PROFICIENCY_IDS as readonly string[]
      ).includes(proficiency)
        ? proficiency
        : 'elementary',
    });
  }
  return languages;
}

/**
 * Drops any update the model got structurally wrong rather than failing
 * the whole turn -- one bad field should never cost the candidate the
 * question they just answered. Same posture as the resume parser's
 * per-entry coercion.
 */
function toUpdates(value: unknown): AssistantFieldUpdate[] {
  if (!Array.isArray(value)) return [];
  const updates: AssistantFieldUpdate[] = [];

  for (const raw of value) {
    if (typeof raw !== 'object' || raw === null) continue;
    const entry = raw as Record<string, unknown>;
    const field = toStr(entry.field) as AssistantWritableField;
    if (!(ASSISTANT_WRITABLE_FIELDS as readonly string[]).includes(field)) {
      continue;
    }
    const confirmation = toStr(entry.confirmation);

    switch (field) {
      case 'expectedCtc': {
        const amount =
          typeof entry.amount === 'number'
            ? entry.amount
            : Number.parseFloat(toStr(entry.amount));
        if (!Number.isFinite(amount) || amount <= 0) continue;
        updates.push({ field, amount, confirmation });
        break;
      }
      case 'noticePeriod': {
        const id = toStr(entry.id);
        if (!(NOTICE_PERIOD_IDS as readonly string[]).includes(id)) continue;
        updates.push({ field, id, confirmation });
        break;
      }
      case 'languages': {
        const languages = toLanguages(entry.languages);
        if (languages.length === 0) continue;
        updates.push({ field, languages, confirmation });
        break;
      }
      case 'skills':
      case 'preferredLocations': {
        const items = toStrArray(entry.items);
        if (items.length === 0) continue;
        updates.push({ field, items, confirmation });
        break;
      }
      default: {
        const text = toStr(entry.text);
        if (!text) continue;
        updates.push({ field, text, confirmation });
        break;
      }
    }
  }

  return updates;
}

export function parseReplyJson(raw: string): Omit<AssistantReply, 'modelId'> {
  let parsed: unknown;
  try {
    parsed = JSON.parse(stripMarkdownFence(raw));
  } catch {
    throw new Error('Gemini returned a non-JSON profile-assistant reply.');
  }
  if (typeof parsed !== 'object' || parsed === null) {
    throw new Error('Gemini returned a non-object profile-assistant reply.');
  }

  const record = parsed as Record<string, unknown>;
  const text = toStr(record.text);
  if (!text) {
    throw new Error('Gemini returned a profile-assistant reply with no text.');
  }

  return {
    text,
    updates: toUpdates(record.updates),
    isComplete: record.isComplete === true,
  };
}
