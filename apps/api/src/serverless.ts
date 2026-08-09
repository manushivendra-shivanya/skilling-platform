import 'reflect-metadata';
import type { IncomingMessage, ServerResponse } from 'http';
import { createNestApp } from './create-app';

type ExpressHandler = (req: IncomingMessage, res: ServerResponse) => void;

/**
 * Cached across warm invocations within the same serverless instance --
 * re-running Nest's DI bootstrap (module graph, provider instantiation)
 * on every single request would defeat the whole point of Vercel Fluid
 * Compute keeping a function instance warm between requests.
 */
let cachedHandler: ExpressHandler | null = null;

async function getHandler(): Promise<ExpressHandler> {
  if (!cachedHandler) {
    const app = await createNestApp();
    await app.init();
    cachedHandler = app.getHttpAdapter().getInstance() as ExpressHandler;
  }
  return cachedHandler;
}

/**
 * `apps/api/api/index.js` requires this file's compiled output
 * (`dist/serverless.js`) directly, rather than letting Vercel's function
 * bundler compile TypeScript from `/api` itself -- keeps this on the
 * exact same `nest build` compilation path (decorators, DI metadata) as
 * every other entry point, instead of trusting a second, independent
 * bundler to handle NestJS's decorator-heavy code correctly.
 */
export default async function handler(
  req: IncomingMessage,
  res: ServerResponse,
): Promise<void> {
  const server = await getHandler();
  server(req, res);
}
