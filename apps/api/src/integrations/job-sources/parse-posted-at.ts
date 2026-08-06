const NO_TIMEZONE_MARKER = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?$/;

/**
 * Parses a source's native date value (an ISO string, an RFC 2822 string,
 * or a Unix millisecond timestamp) into an ISO 8601 string. Falls back to
 * the current time for anything missing or unparseable, rather than
 * throwing -- a bad/missing date on one listing shouldn't drop the whole
 * job or crash the sync, and "just synced" is a reasonable worst case for
 * freshness when the source didn't give us anything better.
 *
 * A date-time string with no trailing "Z"/offset (confirmed live in
 * Jooble's `updated` field, e.g. "2026-07-08T02:57:29.4600000") is
 * treated as UTC, not left to the JS `Date` constructor's default of
 * interpreting it as the server's local timezone -- otherwise the exact
 * same input would parse to a different instant depending on which
 * timezone this process happens to run in.
 */
export function parsePostedAt(value: string | number | undefined | null): string {
  if (value == null) return new Date().toISOString();
  const normalized =
    typeof value === 'string' && NO_TIMEZONE_MARKER.test(value)
      ? `${value}Z`
      : value;
  const date = new Date(normalized);
  if (Number.isNaN(date.getTime())) return new Date().toISOString();
  return date.toISOString();
}
