import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { AppExceptionFilter } from './common/app-exception.filter';
import { RequestIdMiddleware } from './common/request-id.middleware';

/**
 * Vercel's NestJS framework preset auto-detects this file specifically
 * by scanning for a `main.ts`-style entrypoint that directly imports and
 * calls `NestFactory` -- see
 * https://vercel.com/docs/frameworks/backend/nestjs. It then wraps this
 * exact bootstrap (including `app.listen()`) as a Vercel Function itself;
 * no custom `/api` handler or rewrite is needed. An earlier attempt at a
 * custom serverless.ts/api/index.js wrapper actually broke this
 * auto-detection by moving `NestFactory.create()` out of this file --
 * reverted back to the inline form the detector expects.
 */
async function bootstrap() {
  // rawBody: true -- populates request.rawBody (a Buffer) alongside the
  // normal parsed request.body, needed by AuthHooksController to verify
  // Supabase's Standard Webhooks HMAC signature against the exact bytes
  // that were signed. Re-serializing the parsed body would not
  // necessarily match byte-for-byte and would break verification.
  const app = await NestFactory.create(AppModule, { rawBody: true });
  app.use(new RequestIdMiddleware().use);
  app.useGlobalFilters(new AppExceptionFilter());
  app.setGlobalPrefix('v1');

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
}

bootstrap();
