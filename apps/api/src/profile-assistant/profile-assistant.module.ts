import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GoogleGenAI } from '@google/genai';
import { GeminiProfileAssistantProvider } from './gemini-profile-assistant-provider';
import { ProfileAssistantAiProvider } from './profile-assistant-ai-provider';
import { PROFILE_ASSISTANT_AI_PROVIDER } from './profile-assistant-ai-provider.token';
import { ProfileAssistantController } from './profile-assistant.controller';
import { ProfileAssistantService } from './profile-assistant.service';
import { UnconfiguredProfileAssistantProvider } from './unconfigured-profile-assistant-provider';

/**
 * Reuses GEMINI_API_KEY -- the same key coach and resume parsing read.
 * Provider-behind-a-token for the same reason resume.module.ts is: a
 * future fallback provider is one factory branch away.
 */
@Module({
  controllers: [ProfileAssistantController],
  providers: [
    ProfileAssistantService,
    {
      provide: PROFILE_ASSISTANT_AI_PROVIDER,
      useFactory: (config: ConfigService): ProfileAssistantAiProvider => {
        const apiKey = config.get<string>('GEMINI_API_KEY');
        if (!apiKey) return new UnconfiguredProfileAssistantProvider();
        return new GeminiProfileAssistantProvider(new GoogleGenAI({ apiKey }));
      },
      inject: [ConfigService],
    },
  ],
})
export class ProfileAssistantModule {}
