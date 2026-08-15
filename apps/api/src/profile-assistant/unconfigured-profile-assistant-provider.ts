import {
  AssistantReply,
  ProfileAssistantAiProvider,
} from './profile-assistant-ai-provider';

/**
 * Graceful degradation when GEMINI_API_KEY isn't configured -- same
 * posture as unconfigured-resume-parser.ts, including taking no
 * parameters at all. The service maps this thrown error to the same
 * generic "temporarily unavailable" response a real provider failure
 * gets, so a missing key never leaks as a distinguishable error.
 */
export class UnconfiguredProfileAssistantProvider
  implements ProfileAssistantAiProvider
{
  readonly id = 'unconfigured';

  async continueConversation(): Promise<AssistantReply> {
    throw new Error('The profile assistant is not configured.');
  }
}
