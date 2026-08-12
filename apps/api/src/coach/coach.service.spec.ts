import { HttpStatus } from '@nestjs/common';
import { AppError } from '../common/app-error';
import { CoachAiProvider, GenerateReplyParams } from './coach-ai-provider';
import { CoachService } from './coach.service';

class FakeCoachProvider implements CoachAiProvider {
  readonly id = 'fake';
  calls: GenerateReplyParams[] = [];
  reply = { text: 'Here is some guidance.', modelId: 'fake-model' };
  error: Error | null = null;

  async generateReply(params: GenerateReplyParams) {
    this.calls.push(params);
    if (this.error) throw this.error;
    return this.reply;
  }
}

describe('CoachService', () => {
  let provider: FakeCoachProvider;
  let service: CoachService;

  beforeEach(() => {
    provider = new FakeCoachProvider();
    service = new CoachService(provider);
  });

  it('rejects an empty message without calling the provider', async () => {
    await expect(
      service.sendMessage('candidate-1', { message: '   ' }),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
    expect(provider.calls).toHaveLength(0);
  });

  it('rejects a message over the length limit without calling the provider', async () => {
    await expect(
      service.sendMessage('candidate-1', { message: 'x'.repeat(2001) }),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
    expect(provider.calls).toHaveLength(0);
  });

  it('appends the trimmed message to sanitized history and returns the provider reply', async () => {
    const result = await service.sendMessage('candidate-1', {
      message: '  How do I prepare for an interview?  ',
      history: [
        { role: 'candidate', text: 'Hi' },
        { role: 'coach', text: 'Hello! How can I help?' },
        // Invalid entries a buggy/malicious client might send -- must be dropped.
        { role: 'candidate', text: '' } as never,
        { role: 'other', text: 'bad role' } as never,
      ],
    });

    expect(result).toEqual({
      reply: 'Here is some guidance.',
      modelId: 'fake-model',
      provider: 'fake',
    });
    expect(provider.calls).toHaveLength(1);
    expect(provider.calls[0].history).toEqual([
      { role: 'candidate', text: 'Hi' },
      { role: 'coach', text: 'Hello! How can I help?' },
      { role: 'candidate', text: 'How do I prepare for an interview?' },
    ]);
    expect(provider.calls[0].systemPrompt).toContain('Saksham');
  });

  it('caps history sent to the provider at the last 20 turns', async () => {
    const history = Array.from({ length: 30 }, (_, i) => ({
      role: i % 2 === 0 ? ('candidate' as const) : ('coach' as const),
      text: `turn-${i}`,
    }));

    await service.sendMessage('candidate-1', { message: 'latest', history });

    const sent = provider.calls[0].history;
    expect(sent).toHaveLength(21); // last 20 of history + the new message
    expect(sent[0]).toEqual({ role: 'candidate', text: 'turn-10' });
    expect(sent[sent.length - 1]).toEqual({ role: 'candidate', text: 'latest' });
  });

  it('maps a provider failure to a 503 AppError without leaking the underlying error', async () => {
    provider.error = new Error('network blew up');

    await expect(
      service.sendMessage('candidate-1', { message: 'hello' }),
    ).rejects.toMatchObject({
      code: 'COACH_UNAVAILABLE',
      status: HttpStatus.SERVICE_UNAVAILABLE,
    });
  });

  it('rate-limits a candidate after the daily message cap and does not call the provider on the 41st', async () => {
    for (let i = 0; i < 40; i += 1) {
      await service.sendMessage('candidate-1', { message: `message ${i}` });
    }
    expect(provider.calls).toHaveLength(40);

    await expect(
      service.sendMessage('candidate-1', { message: 'one more' }),
    ).rejects.toMatchObject({ code: 'RATE_LIMITED' });
    expect(provider.calls).toHaveLength(40);
  });

  it('tracks the daily cap independently per candidate', async () => {
    for (let i = 0; i < 40; i += 1) {
      await service.sendMessage('candidate-1', { message: `message ${i}` });
    }

    await expect(
      service.sendMessage('candidate-2', { message: 'hello' }),
    ).resolves.toEqual({
      reply: 'Here is some guidance.',
      modelId: 'fake-model',
      provider: 'fake',
    });
  });

  it('re-throws AppError instances from validation as-is (sanity: AppError is an Error)', async () => {
    await expect(
      service.sendMessage('candidate-1', { message: '' }),
    ).rejects.toBeInstanceOf(AppError);
  });
});
