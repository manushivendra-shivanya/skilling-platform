import { Inject, Injectable } from '@nestjs/common';
import { AppError } from '../common/app-error';
import { CoachAiProvider, CoachTurn } from './coach-ai-provider';
import { COACH_AI_PROVIDER } from './coach-ai-provider.token';
import {
  buildCoachSystemPrompt,
  CoachSectorPackId,
} from './coach.system-prompt';

const MAX_MESSAGE_LENGTH = 2000;
// Bounds how much history (and therefore token cost) one request can carry
// -- the client is expected to manage its own transcript, but nothing
// stops a buggy or malicious client sending an unbounded array.
const MAX_HISTORY_TURNS = 20;
// Per-candidate-per-day, held in memory only (see the ephemeral-history
// decision -- this backend keeps no coach data at rest). Resets on
// restart/redeploy, which is an accepted trade-off for v1: the cost this
// guards against is runaway API spend, not a hard entitlement.
const RATE_LIMIT_PER_DAY = 40;

export interface CoachMessageRequest {
  message: string;
  history?: CoachTurn[];
  sectorPackId?: CoachSectorPackId;
}

export interface CoachMessageResult {
  reply: string;
  modelId: string;
  provider: string;
}

@Injectable()
export class CoachService {
  private readonly dailyMessageCounts = new Map<
    string,
    { day: string; count: number }
  >();

  constructor(
    @Inject(COACH_AI_PROVIDER) private readonly provider: CoachAiProvider,
  ) {}

  async sendMessage(
    candidateId: string,
    request: CoachMessageRequest,
  ): Promise<CoachMessageResult> {
    const message = request.message?.trim() ?? '';
    if (!message) {
      throw AppError.validation('Enter a message before sending.');
    }
    if (message.length > MAX_MESSAGE_LENGTH) {
      throw AppError.validation(
        `Messages must be ${MAX_MESSAGE_LENGTH} characters or fewer.`,
      );
    }

    this.enforceRateLimit(candidateId);

    const history = this.sanitizeHistory(request.history);
    const systemPrompt = buildCoachSystemPrompt(request.sectorPackId);

    try {
      const reply = await this.provider.generateReply({
        systemPrompt,
        history: [...history, { role: 'candidate', text: message }],
      });
      return {
        reply: reply.text,
        modelId: reply.modelId,
        provider: this.provider.id,
      };
    } catch {
      throw AppError.serviceUnavailable(
        'COACH_UNAVAILABLE',
        'The AI coach is temporarily unavailable. Please try again in a moment.',
      );
    }
  }

  private sanitizeHistory(history: CoachTurn[] | undefined): CoachTurn[] {
    if (!Array.isArray(history)) {
      return [];
    }
    const valid = history.filter(
      (turn): turn is CoachTurn =>
        (turn?.role === 'candidate' || turn?.role === 'coach') &&
        typeof turn?.text === 'string' &&
        turn.text.trim().length > 0,
    );
    return valid.slice(-MAX_HISTORY_TURNS);
  }

  private enforceRateLimit(candidateId: string): void {
    const today = new Date().toISOString().slice(0, 10);
    const existing = this.dailyMessageCounts.get(candidateId);
    if (!existing || existing.day !== today) {
      this.dailyMessageCounts.set(candidateId, { day: today, count: 1 });
      return;
    }
    if (existing.count >= RATE_LIMIT_PER_DAY) {
      throw AppError.rateLimited(
        "You have reached today's message limit for the AI coach. Please try again tomorrow.",
      );
    }
    existing.count += 1;
  }
}
