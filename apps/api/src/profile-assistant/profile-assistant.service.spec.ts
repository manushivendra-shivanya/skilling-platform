import { AppError } from '../common/app-error';
import {
  AssistantReply,
  ContinueConversationParams,
  ProfileAssistantAiProvider,
} from './profile-assistant-ai-provider';
import { ProfileAssistantService } from './profile-assistant.service';

class FakeProvider implements ProfileAssistantAiProvider {
  readonly id = 'fake';
  lastParams?: ContinueConversationParams;
  reply: AssistantReply = {
    text: 'What is your notice period?',
    updates: [],
    isComplete: false,
    modelId: 'fake-model',
  };
  shouldThrow = false;

  async continueConversation(
    params: ContinueConversationParams,
  ): Promise<AssistantReply> {
    this.lastParams = params;
    if (this.shouldThrow) throw new Error('provider exploded');
    return this.reply;
  }
}

function serviceWith(provider: ProfileAssistantAiProvider) {
  return new ProfileAssistantService(provider);
}

describe('ProfileAssistantService', () => {
  it('returns the provider reply along with the provider id', async () => {
    const provider = new FakeProvider();

    const result = await serviceWith(provider).continueConversation('c1', {
      remainingFields: ['noticePeriod'],
      history: [],
    });

    expect(result.text).toBe('What is your notice period?');
    expect(result.provider).toBe('fake');
    expect(result.modelId).toBe('fake-model');
  });

  it('filters out fields the assistant cannot write before prompting', async () => {
    const provider = new FakeProvider();

    await serviceWith(provider).continueConversation('c1', {
      remainingFields: ['noticePeriod', 'workExperience', 'nonsense'],
      history: [],
    });

    expect(provider.lastParams?.remainingFields).toEqual(['noticePeriod']);
  });

  it('defaults the language tag to English when none is sent', async () => {
    const provider = new FakeProvider();

    await serviceWith(provider).continueConversation('c1', {});

    expect(provider.lastParams?.languageTag).toBe('en');
  });

  it('drops an update for a field outside the writable list', async () => {
    const provider = new FakeProvider();
    provider.reply = {
      ...provider.reply,
      updates: [
        { field: 'headline', text: 'Associate', confirmation: 'ok' },
        {
          field: 'workExperience' as never,
          text: 'nope',
          confirmation: 'ok',
        },
      ],
    };

    const result = await serviceWith(provider).continueConversation('c1', {
      remainingFields: ['headline'],
    });

    expect(result.updates).toHaveLength(1);
    expect(result.updates[0].field).toBe('headline');
  });

  it('treats a turn with nothing left to ask about as complete', async () => {
    const provider = new FakeProvider();
    provider.reply = { ...provider.reply, isComplete: false };

    const result = await serviceWith(provider).continueConversation('c1', {
      remainingFields: [],
    });

    expect(result.isComplete).toBe(true);
  });

  it('rejects a conversation that has run too long', async () => {
    const history = Array.from({ length: 41 }, () => ({
      role: 'candidate' as const,
      text: 'hi',
    }));

    await expect(
      serviceWith(new FakeProvider()).continueConversation('c1', { history }),
    ).rejects.toBeInstanceOf(AppError);
  });

  it('rejects a single oversized message', async () => {
    await expect(
      serviceWith(new FakeProvider()).continueConversation('c1', {
        history: [{ role: 'candidate', text: 'x'.repeat(2001) }],
      }),
    ).rejects.toBeInstanceOf(AppError);
  });

  it('maps a provider failure to a generic unavailable error', async () => {
    const provider = new FakeProvider();
    provider.shouldThrow = true;

    await expect(
      serviceWith(provider).continueConversation('c1', {}),
    ).rejects.toMatchObject({ code: 'PROFILE_ASSISTANT_UNAVAILABLE' });
  });

  it('rate-limits a candidate who will not stop talking', async () => {
    const service = serviceWith(new FakeProvider());

    for (let i = 0; i < 120; i += 1) {
      await service.continueConversation('chatty', {});
    }

    await expect(
      service.continueConversation('chatty', {}),
    ).rejects.toBeInstanceOf(AppError);
    // Scoped per candidate -- someone else is unaffected.
    await expect(
      service.continueConversation('someone-else', {}),
    ).resolves.toBeDefined();
  });
});
