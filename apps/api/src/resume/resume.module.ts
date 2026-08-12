import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GoogleGenAI } from '@google/genai';
import { GeminiResumeParser } from './gemini-resume-parser';
import { ResumeAiProvider } from './resume-ai-provider';
import { RESUME_AI_PROVIDER } from './resume-ai-provider.token';
import { ResumeController } from './resume.controller';
import { ResumeService } from './resume.service';
import { UnconfiguredResumeParser } from './unconfigured-resume-parser';

/**
 * Only one real provider today (Gemini, reusing GEMINI_API_KEY -- the
 * same key Coach uses, same as how coach.module.ts reads it). Structured
 * as a provider-behind-a-token the same way coach.module.ts is even
 * though there's no second provider to switch to yet, so a future
 * fallback (mirroring AnthropicCoachProvider) is one factory branch away,
 * not a ResumeService rewrite.
 */
@Module({
  controllers: [ResumeController],
  providers: [
    ResumeService,
    {
      provide: RESUME_AI_PROVIDER,
      useFactory: (config: ConfigService): ResumeAiProvider => {
        const apiKey = config.get<string>('GEMINI_API_KEY');
        if (!apiKey) return new UnconfiguredResumeParser();
        return new GeminiResumeParser(new GoogleGenAI({ apiKey }));
      },
      inject: [ConfigService],
    },
  ],
})
export class ResumeModule {}
