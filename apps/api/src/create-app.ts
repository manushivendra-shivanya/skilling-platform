import { INestApplication } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { AppExceptionFilter } from './common/app-exception.filter';
import { RequestIdMiddleware } from './common/request-id.middleware';

/**
 * Shared app construction for both entry points: `main.ts` (local dev,
 * calls `app.listen()`) and `serverless.ts` (Vercel, calls `app.init()`
 * and hands the underlying Express instance to Vercel's Node runtime
 * directly instead of binding a port). Keeps the
 * middleware/filter/prefix setup in exactly one place rather than
 * duplicated across both.
 */
export async function createNestApp(): Promise<INestApplication> {
  const app = await NestFactory.create(AppModule);
  app.use(new RequestIdMiddleware().use);
  app.useGlobalFilters(new AppExceptionFilter());
  app.setGlobalPrefix('v1');
  return app;
}
