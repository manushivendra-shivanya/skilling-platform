import { createHash } from 'crypto';

/** Employer API keys are never stored raw -- only this hash is persisted. */
export function hashApiKey(key: string): string {
  return createHash('sha256').update(key).digest('hex');
}
