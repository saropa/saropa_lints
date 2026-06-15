/**
 * Shared builders for the gold-standard editor-area dashboard hero band (guideline §4.1).
 *
 * Every editor-area dashboard renders the same hero shape:
 *
 *   ┌─────────────────────────────────────────────────────────┐
 *   │  Saropa <Title> v<version>            [↔]   [Gauge]     │
 *   │  ⟳ Last run … · N findings · …                          │
 *   └─────────────────────────────────────────────────────────┘
 *
 * Dashboards supply their own status pills and (optionally) a radial gauge SVG. The
 * "Saropa " prefix on the title is enforced here — pass the bare product noun
 * ("Findings Dashboard", "Package Dashboard", "Code Health") and the helper prepends
 * the brand prefix per guideline §8.1. Sidebar webviews and tree views must NOT use
 * this helper.
 *
 * The full-width toggle (`[↔]`) flips `body[data-full-width]` so users on ultrawide
 * monitors can override the body max-width set in dashboardChromeStyles.ts. The
 * toggle is wired by the inline script returned from `getFullWidthToggleScript()`.
 */

/** Inputs for the shared dashboard hero builder. */
export interface DashboardHeroInput {
  /**
   * Bare product noun for the page title; the helper prepends "Saropa " (guideline §8.1).
   * Pass "Findings Dashboard", NOT "Saropa Findings Dashboard". The full-document
   * `<title>` is the same string the helper builds for `<h1>`.
   */
  title: string;
  /** Extension/build version (without the "v" prefix). Rendered as a muted stamp. */
  version?: string;
  /** Pre-built status-pill HTML (use `buildStatusLine`). Empty string suppresses the line. */
  statusLineHtml?: string;
  /** Pre-built gauge HTML (radial SVG). Empty string places no gauge in the hero. */
  gaugeHtml?: string;
  /** When true, renders the full-width toggle button. Defaults to true. */
  showFullWidthToggle?: boolean;
  /**
   * Extra inline HTML rendered alongside the full-width toggle at the
   * trailing edge of the status line. Used for surface-specific affordances
   * like the keyboard-shortcut overlay trigger (§15.2). Already-escaped
   * HTML — surfaces that pass dynamic strings must escape themselves.
   */
  extraToggleHtml?: string;
}

/** One status-line pill: a muted facts cell rendered in a row under the title. */
export interface StatusPill {
  /** Plain text label (no HTML; will be escaped). */
  label: string;
  /** Optional tone — `good` / `warn` / `bad` / `neutral` (default). */
  tone?: 'good' | 'warn' | 'bad' | 'neutral';
  /** Optional `title` tooltip. Plain text only — escaped. */
  title?: string;
  /** Optional leading glyph (e.g. `⟳`). Single character; not escaped, kept raw. */
  glyph?: string;
  /**
   * When set, the pill renders as an interactive `<button id="{actionId}">`
   * (still styled as a pill via `.pill.pill-action`) instead of an inert
   * `<span>`. The surface's own script wires the click by this id. Used for the
   * "Scanned X ago" pill so clicking it can trigger a rescan + update re-check.
   */
  actionId?: string;
}

import { l10n } from '../i18n/runtime';

function escape(s: string): string {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

/** Render a row of status pills as the muted under-title status line (guideline §4.1). */
export function buildStatusLine(pills: readonly StatusPill[]): string {
  if (pills.length === 0) return '';
  const parts = pills.map((p) => {
    const toneClass = p.tone && p.tone !== 'neutral' ? ` ${p.tone}` : '';
    const titleAttr = p.title ? ` title="${escape(p.title)}"` : '';
    const glyph = p.glyph ? `${p.glyph} ` : '';
    const body = `${glyph}${escape(p.label)}`;
    // Interactive pills become real buttons so they are keyboard-focusable and
    // get the native click/Enter/Space semantics; inert pills stay spans.
    if (p.actionId) {
      return `<button type="button" class="pill pill-action${toneClass}" id="${escape(p.actionId)}"${titleAttr}>${body}</button>`;
    }
    return `<span class="pill${toneClass}"${titleAttr}>${body}</span>`;
  });
  return `<p class="status-line">${parts.join('<span class="dot">·</span>')}</p>`;
}

/** Render the full-width toggle icon button. Wired by `getFullWidthToggleScript()`. */
export function buildFullWidthToggle(): string {
  // The arrow glyph (↔) telegraphs "expand horizontally". The active state styling
  // (when body[data-full-width="true"]) lives in dashboardChromeStyles.ts.
  return `<button type="button" class="full-width-toggle" id="dashFullWidthToggle"
    title="${escape(l10n('a11y.toggleFullWidth'))}" aria-label="${escape(l10n('a11y.toggleFullWidth'))}"
    aria-pressed="false">↔</button>`;
}

/**
 * Render the gold-standard hero band: title (Saropa-prefixed), version stamp, status line,
 * full-width toggle, and optional gauge. Guideline §4.1 + §8.1.
 *
 * The full-width toggle is appended to the status line (right-aligned via `margin-inline-start:auto`)
 * rather than dropped into a separate hero cell — that keeps the existing 2-column hero
 * grid (text | gauge) intact and avoids collision with the gauge in dashboards that have one.
 */
export function buildDashboardHero(input: DashboardHeroInput): string {
  const stamp = input.version
    ? `<span class="stamp">v${escape(input.version)}</span>`
    : '';
  const gauge = input.gaugeHtml ?? '';
  const toggle = input.showFullWidthToggle === false ? '' : buildFullWidthToggle();
  const extra = input.extraToggleHtml ?? '';
  // Trailing actions: full-width toggle + any surface-specific buttons (e.g. the
  // keyboard-shortcut overlay trigger, §15.2). Order is fixed (extra before toggle)
  // so the toggle stays at the far right edge — that position is sticky in muscle
  // memory across all dashboards.
  const trailing = `${extra}${toggle}`;
  const status = input.statusLineHtml ?? '';
  // If there's no status line, render a bare row that just holds the trailing actions.
  // This keeps the toggle reachable on dashboards that opt out of status pills (About, etc.).
  const statusWithToggle = status
    ? status.replace('</p>', `${trailing}</p>`)
    : (trailing ? `<p class="status-line">${trailing}</p>` : '');
  const title = `Saropa ${input.title}`;
  return `<header class="dash-hero">
    <div class="hero-text">
      <h1>${escape(title)}${stamp}</h1>
      ${statusWithToggle}
    </div>
    ${gauge}
  </header>`;
}

/** Build the document `<title>` string with the Saropa prefix applied (guideline §8.1). */
export function buildDocumentTitle(productNoun: string): string {
  return `Saropa ${productNoun}`;
}

/**
 * Inline script that wires the full-width toggle.
 * Idempotent: silently does nothing if `#dashFullWidthToggle` isn't in the DOM, so
 * dashboards that opt out of the toggle don't need to strip the script.
 */
export function getFullWidthToggleScript(): string {
  return `(function() {
    var btn = document.getElementById('dashFullWidthToggle');
    if (!btn) return;
    function setState(on) {
      document.body.setAttribute('data-full-width', on ? 'true' : 'false');
      btn.setAttribute('aria-pressed', on ? 'true' : 'false');
    }
    btn.addEventListener('click', function() {
      var on = document.body.getAttribute('data-full-width') === 'true';
      setState(!on);
    });
  })();`;
}

/** Format a UTC ISO 8601 timestamp as a relative duration ("just now", "2m ago", "3d ago"). */
export function formatRelativeTimestamp(iso: string | undefined): string | undefined {
  if (!iso) return undefined;
  const t = Date.parse(iso);
  if (!Number.isFinite(t)) return undefined;
  const diffMs = Date.now() - t;
  if (diffMs < 0) return 'just now';
  const sec = Math.floor(diffMs / 1000);
  if (sec < 45) return 'just now';
  const min = Math.floor(sec / 60);
  if (min < 60) return `${min}m ago`;
  const hr = Math.floor(min / 60);
  if (hr < 24) return `${hr}h ago`;
  const day = Math.floor(hr / 24);
  return `${day}d ago`;
}

/* ──────────────────────────────────────────────────────────────────────
 * §15 — Accessibility scaffolding.
 *
 * Three reusable HTML fragments every dashboard should compose into its
 * body so a11y patterns are consistent across surfaces:
 *
 *   - [buildSkipLink] — visible-on-focus link that jumps the user past
 *     the hero / toolbar to the primary content (§15.2).
 *   - [buildAnnouncer] — single polite live region for filter / sort
 *     change announcements (§15.3); script wires it via [announce].
 *   - [getAnnouncerScript] — client-side helper that surface scripts
 *     can include to update the announcer text safely.
 * ──────────────────────────────────────────────────────────────────── */

/**
 * Render a "Skip to {target}" keyboard-only affordance. The link is hidden
 * off-screen by default and only becomes visible when keyboard-focused.
 *
 * @param targetId — id of the element the skip link jumps to. Surfaces
 *   typically point at the primary table or the data section the user
 *   cares about (e.g. `findings-table`, `pvBody`).
 * @param label — the visible-on-focus text. Defaults to "Skip to content".
 */
export function buildSkipLink(targetId: string, label = 'Skip to content'): string {
  return `<a href="#${escape(targetId)}" class="skip-link">${escape(label)}</a>`;
}

/**
 * Render the polite live-region announcer that surfaces inject filter /
 * sort / count change messages into (§15.3). Single instance per page.
 *
 * Place once near the top of the body, after the skip link. Pair with
 * [getAnnouncerScript] so client code can call `announce('47 of 200 rows visible')`.
 */
export function buildAnnouncer(): string {
  return `<div id="announcer" role="status" aria-live="polite" aria-atomic="true"></div>`;
}

/**
 * Inline script that exposes a global `announce(message)` helper writing
 * to `#announcer`. Idempotent — multiple includes on the same page are
 * harmless because the function checks for the element each call.
 *
 * Surfaces should debounce ≥ 300ms before calling so a typing burst does
 * not produce one announcement per keystroke (§15.3).
 */
export function getAnnouncerScript(): string {
  return `function announce(message) {
    var el = document.getElementById('announcer');
    if (!el) { return; }
    // Re-set to empty first so consecutive identical announcements still fire.
    el.textContent = '';
    setTimeout(function() { el.textContent = message; }, 50);
  }`;
}
