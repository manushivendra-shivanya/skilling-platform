import { Inject, Injectable } from '@nestjs/common';
import { AppError } from '../common/app-error';
import {
  ASSISTANT_WRITABLE_FIELDS,
  AssistantFieldUpdate,
  AssistantTurn,
  AssistantWritableField,
  ProfileAssistantAiProvider,
} from './profile-assistant-ai-provider';
import { PROFILE_ASSISTANT_AI_PROVIDER } from './profile-assistant-ai-provider.token';

// A conversation this long has stopped being "finish your profile" and
// become something else -- bound it rather than letting token cost run.
const MAX_HISTORY_TURNS = 40;
const MAX_TURN_LENGTH = 2000;
const MAX_DIGEST_LENGTH = 4000;
// Higher than resume parsing's 10/day: this is a back-and-forth, so one
// completion session is legitimately many calls. Same in-memory,
// resets-on-restart posture as CoachService's own limit.
const RATE_LIMIT_PER_DAY = 120;

export interface ProfileAssistantRequestBody {
  knownProfileDigest?: string;
  remainingFields?: string[];
  history?: AssistantTurn[];
  languageTag?: string;
}

export interface ProfileAssistantResponse {
  text: string;
  updates: AssistantFieldUpdate[];
  isComplete: boolean;
  modelId: string;
  provider: string;
}

@Injectable()
export class ProfileAssistantService {
  private readonly dailyTurnCounts = new Map<
    string,
    { day: string; count: number }
  >();

  constructor(
    @Inject(PROFILE_ASSISTANT_AI_PROVIDER)
    private readonly provider: ProfileAssistantAiProvider,
  ) {}

  async continueConversation(
    candidateId: string,
    body: ProfileAssistantRequestBody,
  ): Promise<ProfileAssistantResponse> {
    const history = body.history ?? [];
    if (history.length > MAX_HISTORY_TURNS) {
      throw AppError.validation(
        'This conversation is too long. Start a new one to continue.',
      );
    }
    if (history.some((turn) => (turn.text?.length ?? 0) > MAX_TURN_LENGTH)) {
      throw AppError.validation('That message is too long.');
    }

    // Drop anything the assistant can't actually write rather than
    // passing it through to the prompt -- an unknown field name would
    // make the model ask a question whose answer has nowhere to go.
    const remainingFields = (body.remainingFields ?? []).filter(
      (field): field is AssistantWritableField =>
        (ASSISTANT_WRITABLE_FIELDS as readonly string[]).includes(field),
    );

    this.enforceRateLimit(candidateId);

    try {
      const reply = await this.provider.continueConversation({
        knownProfileDigest: (body.knownProfileDigest ?? '').slice(
          0,
          MAX_DIGEST_LENGTH,
        ),
        remainingFields,
        history,
        languageTag: body.languageTag?.trim() || 'en',
      });

      return {
        text: reply.text,
        // Belt-and-braces against a provider that skipped its own
        // validation: never hand the client an update for a field the
        // conversation wasn't about.
        updates: reply.updates.filter((update) =>
          (ASSISTANT_WRITABLE_FIELDS as readonly string[]).includes(
            update.field,
          ),
        ),
        // A turn that filled the last remaining field is complete even if
        // the model forgot to say so -- the field list is the source of
        // truth about what's left, not the model's own bookkeeping.
        isComplete:
          reply.isComplete ||
          remainingFields.length === 0 ||
          reply.updates.length >= remainingFields.length,
        modelId: reply.modelId,
        provider: this.provider.id,
      };
    } catch (error) {
      if (error instanceof AppError) throw error;
      throw AppError.serviceUnavailable(
        'PROFILE_ASSISTANT_UNAVAILABLE',
        'The profile assistant is temporarily unavailable. Please try again in a moment.',
      );
    }
  }

  private enforceRateLimit(candidateId: string): void {
    const today = new Date().toISOString().slice(0, 10);
    const existing = this.dailyTurnCounts.get(candidateId);
    if (!existing || existing.day !== today) {
      this.dailyTurnCounts.set(candidateId, { day: today, count: 1 });
      return;
    }
    if (existing.count >= RATE_LIMIT_PER_DAY) {
      throw AppError.rateLimited(
        "You have reached today's assistant limit. Please try again tomorrow.",
      );
    }
    existing.count += 1;
  }
}
