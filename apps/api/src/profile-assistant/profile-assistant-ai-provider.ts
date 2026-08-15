/**
 * The fields the assistant is allowed to fill by conversation.
 *
 * Deliberately a subset of everything a profile holds: work experience
 * and education are *structured, repeating* entries (a job has a title, a
 * company, and a date range that must agree with each other), and getting
 * those wrong by mishearing one clause is worse than not asking at all.
 * The assistant can tell a candidate those sections are empty -- it just
 * routes them to the existing form rather than transcribing them itself.
 *
 * Mirrors `ProfileGapId` on the mobile side, minus those two. Any value
 * the model returns outside this list is dropped by the service.
 */
export const ASSISTANT_WRITABLE_FIELDS = [
  'headline',
  'summary',
  'totalExperience',
  'phone',
  'email',
  'skills',
  'languages',
  'noticePeriod',
  'expectedCtc',
  'preferredLocations',
] as const;

export type AssistantWritableField = (typeof ASSISTANT_WRITABLE_FIELDS)[number];

/** Valid `noticePeriod` ids -- must match mobile's `NoticePeriod` enum. */
export const NOTICE_PERIOD_IDS = [
  'immediate',
  'fifteen_days',
  'one_month',
  'two_months',
  'three_months',
  'serving_notice',
] as const;

/**
 * Valid language proficiency ids -- must match mobile's
 * `LanguageProficiency` enum.
 */
export const LANGUAGE_PROFICIENCY_IDS = [
  'native',
  'fluent',
  'professional_working',
  'elementary',
] as const;

export interface AssistantLanguageValue {
  language: string;
  proficiency: string;
}

/**
 * One field the assistant heard an answer for.
 *
 * Only one of the value slots is ever populated, chosen by `field` --
 * a discriminated union would be tidier, but this shape survives a
 * defensive JSON parse from a language model far more simply, and the
 * service validates the right slot per field anyway.
 */
export interface AssistantFieldUpdate {
  field: AssistantWritableField;
  /** Free text (headline/summary/totalExperience/phone/email). */
  text?: string;
  /** `expectedCtc`, annual, in rupees. */
  amount?: number;
  /** `skills` / `preferredLocations`. */
  items?: string[];
  /** `languages`. */
  languages?: AssistantLanguageValue[];
  /** `noticePeriod`, one of NOTICE_PERIOD_IDS. */
  id?: string;
  /**
   * A short, already-localized confirmation the model writes in the
   * candidate's own language ("15 days set kar diya") -- shown back to
   * them as the assistant's acknowledgement. Not used for storage.
   */
  confirmation: string;
}

export interface AssistantTurn {
  role: 'assistant' | 'candidate';
  text: string;
}

export interface AssistantReply {
  /** What the assistant says next -- a question, or a closing message. */
  text: string;
  updates: AssistantFieldUpdate[];
  /** True when the assistant has nothing left worth asking about. */
  isComplete: boolean;
  /** Recorded for auditability -- same convention as CoachReply. */
  modelId: string;
}

export interface ContinueConversationParams {
  /**
   * What's already known, as a compact human-readable digest -- never
   * the raw profile row. The assistant needs enough context not to ask
   * about something already answered, and nothing more.
   */
  knownProfileDigest: string;
  /** Field names still missing, highest-cost first. */
  remainingFields: AssistantWritableField[];
  /**
   * Client-supplied on every call and never persisted server-side --
   * the same stateless posture CoachService takes (see its doc comment).
   */
  history: AssistantTurn[];
  /** BCP-47-ish tag from the app's own locale: `en`, `hi`, or `hi_Latn`. */
  languageTag: string;
}

export interface ProfileAssistantAiProvider {
  readonly id: string;
  continueConversation(
    params: ContinueConversationParams,
  ): Promise<AssistantReply>;
}
