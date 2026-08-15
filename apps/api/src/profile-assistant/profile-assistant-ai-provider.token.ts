/**
 * Injection token for whichever ProfileAssistantAiProvider
 * profile-assistant.module.ts constructs -- the service depends on this
 * token, never on a concrete provider. Same plain-string convention as
 * coach/resume's own tokens.
 */
export const PROFILE_ASSISTANT_AI_PROVIDER = 'PROFILE_ASSISTANT_AI_PROVIDER';
