import { EvidenceWithFreshness } from '../employer/employer-evidence';
import { CAREER_PASSPORT_DISCLAIMER } from './career-passport.service';

/**
 * Server-rendered, read-only pages for the public share link
 * (`GET /career-passport/share/:token`). Deliberately not a template
 * engine -- the API has none as a dependency today and this is two small,
 * static-shaped pages, not a growing surface.
 */

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

const PAGE_STYLE = `
  :root { color-scheme: light dark; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    max-width: 640px;
    margin: 0 auto;
    padding: 24px;
    line-height: 1.5;
  }
  .disclaimer { font-style: italic; }
  .boundary {
    border: 2px solid #1d4ed8;
    background: #eff6ff;
    border-radius: 8px;
    padding: 12px 14px;
    margin: 16px 0;
    font-weight: 600;
  }
  .evidence-card {
    border: 1px solid #d1d5db;
    border-radius: 8px;
    padding: 12px 14px;
    margin-bottom: 10px;
  }
  .evidence-title { font-weight: 600; }
  .chip {
    display: inline-block;
    font-size: 12px;
    font-weight: 600;
    padding: 2px 8px;
    border-radius: 999px;
    margin-right: 6px;
    margin-top: 6px;
    background: #e5e7eb;
    color: #111827;
  }
  .chip.active { background: #dcfce7; color: #166534; }
  .chip.stale { background: #fef3c7; color: #78350f; }
  .chip.superseded { background: #e5e7eb; color: #374151; }
`;

function pageShell(title: string, body: string): string {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<meta name="robots" content="noindex, nofollow" />
<title>${escapeHtml(title)}</title>
<style>${PAGE_STYLE}</style>
</head>
<body>
${body}
</body>
</html>`;
}

export function renderSharedEvidencePage(evidence: EvidenceWithFreshness[]): string {
  const cards = evidence.length
    ? evidence
        .map(
          (item) => `
  <div class="evidence-card">
    <div class="evidence-title">${escapeHtml(item.title)}</div>
    <p>${escapeHtml(item.description)}</p>
    <span class="chip">${escapeHtml(item.competencyId)}</span>
    <span class="chip ${escapeHtml(item.freshness)}">${escapeHtml(item.freshness)}</span>
    <span class="chip">${item.score}%</span>
  </div>`,
        )
        .join('\n')
    : '<p>This candidate has no evidence to show yet.</p>';

  return pageShell(
    'Shared Career Passport',
    `
<h1>Career Passport</h1>
<p class="disclaimer">${escapeHtml(CAREER_PASSPORT_DISCLAIMER)}</p>
<p class="boundary">This is a read-only view shared by the candidate. Flora does not rank, shortlist or certify candidates.</p>
${cards}`,
  );
}

const UNAVAILABLE_MESSAGES: Record<'not_found' | 'revoked' | 'expired', string> = {
  not_found: 'This link does not exist.',
  revoked: 'This link has been revoked by the candidate and is no longer available.',
  expired: 'This link has expired.',
};

export function renderShareLinkUnavailablePage(
  reason: 'not_found' | 'revoked' | 'expired',
): string {
  return pageShell(
    'Link unavailable',
    `
<h1>Link unavailable</h1>
<p>${escapeHtml(UNAVAILABLE_MESSAGES[reason])}</p>`,
  );
}
