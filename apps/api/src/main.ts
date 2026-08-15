import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
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
  // `bodyParser: false` suppresses Nest's own parser registration so the
  // explicit ones below are the only ones in the chain. Re-registering on
  // top of the defaults would not work: body-parser rejects an
  // over-limit request at the *first* parser it hits, so the default
  // 100kb json parser would 413 an upload before a larger one ever ran.
  //
  // Why a larger limit at all: `POST /v1/resume/parse-document` carries a
  // base64-encoded resume file, which ResumeService bounds at 5MB of
  // bytes -- about 6.7MB once base64 inflates it by a third. At the
  // default that upload dies in the transport with an unexplained
  // failure instead of the service's own "that file is too large"
  // message. 8mb keeps the service, not body-parser, as the thing that
  // enforces the ceiling.
  //
  // `app.useBodyParser` passes `rawBody: true` through from the options
  // above (see NestApplication.useBodyParser), so AuthHooksController's
  // Standard Webhooks signature check still sees `request.rawBody`.
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    rawBody: true,
    bodyParser: false,
  });
  app.useBodyParser('json', { limit: '8mb' });
  app.useBodyParser('urlencoded', { limit: '8mb', extended: true });
  app.use(new RequestIdMiddleware().use);
  app.useGlobalFilters(new AppExceptionFilter());
  app.setGlobalPrefix('v1');

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
}

bootstrap();
