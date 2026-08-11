import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GoogleGenAI } from '@google/genai';
import Anthropic from '@anthropic-ai/sdk';
import { AnthropicCoachProvider } from './anthropic-coach-provider';
import { CoachAiProvider } from './coach-ai-provider';
import { COACH_AI_PROVIDER } from './coach-ai-provider.token';
import { CoachController } from './coach.controller';
import { CoachService } from './coach.service';
import { GeminiCoachProvider } from './gemini-coach-provider';
import { UnconfiguredCoachProvider } from './unconfigured-coach-provider';

/**
 * COACH_MODEL_PROVIDER selects the active provider -- "gemini" (default)
 * or "anthropic". This is the whole mechanism behind "configure the Claude
 * Sonnet 5 fallback now, switch to it later": AnthropicCoachProvider is
 * built and tested to the same standard as GeminiCoachProvider, just not
 * selected by default. Switching providers is one env var, not a
 * deployment.
 */
@Module({
  controllers: [CoachController],
  providers: [
    CoachService,
    {
      provide: COACH_AI_PROVIDER,
      useFactory: (config: ConfigService): CoachAiProvider => {
        const selected = (
          config.get<string>('COACH_MODEL_PROVIDER') ?? 'gemini'
        ).toLowerCase();

        if (selected === 'anthropic') {
          const apiKey = config.get<string>('ANTHROPIC_API_KEY');
          if (!apiKey) return new UnconfiguredCoachProvider();
          return new AnthropicCoachProvider(new Anthropic({ apiKey }));
        }

        const apiKey = config.get<string>('GEMINI_API_KEY');
        if (!apiKey) return new UnconfiguredCoachProvider();
        return new GeminiCoachProvider(new GoogleGenAI({ apiKey }));
      },
      inject: [ConfigService],
    },
  ],
})
export class CoachModule {}
