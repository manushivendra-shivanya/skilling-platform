/**
 * Simple tag-stripping for Greenhouse/Lever descriptions, which return
 * HTML. No rich-text rendering exists anywhere else in this app, so a
 * plain-text description is enough here rather than adding an HTML
 * parser dependency. If either provider's markup turns out to carry more
 * than plain tags (embedded scripts/styles), this needs revisiting --
 * see docs/25's flagged uncertainty.
 */
export function stripHtml(html: string | undefined | null): string {
  if (!html) return '';
  return html
    .replace(/<[^>]*>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}
