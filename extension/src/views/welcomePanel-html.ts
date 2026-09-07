import { createWebviewCspNonce, escapeHtml } from '../vibrancy/views/html-utils';
import { l10n } from '../i18n/runtime';
import { getDashboardChromeStyles } from './dashboardChromeStyles';
import { buildDashboardHero } from './dashboardHero';
import { getWelcomePanelStyles } from './welcomePanel-styles';
import { getWelcomePanelScript } from './welcomePanel-script';
import { buildWelcomeStats, type WelcomeStat } from './welcomePanelStats';
import type { RuleCountSummary } from './ruleCountCliRunner';

interface WelcomeAction {
  label: string;
  action: string;
}

interface WelcomeCard {
  icon: string;
  header: string;
  body: string;
  why: string;
  actions: WelcomeAction[];
  /** Marks the engine-swap card so it renders with elevated visual weight — this is a
   * default-behavior change to the diagnostic engine, not a routine feature note. */
  critical?: boolean;
  /** Chrome accent token (without `var()`) for the card's left border, when not critical. */
  tone?: string;
}

interface DiscoveryTile {
  icon: string;
  label: string;
  description: string;
  action: string;
}

/** Direct links into the other webview dashboards — the "where do I go next" surface
 * this panel exists to answer, distinct from the upgrade-specific cards above. */
function buildDiscoveryTiles(): DiscoveryTile[] {
  return [
    { icon: '🔍', label: l10n('welcome.discover.findings.label'), description: l10n('welcome.discover.findings.description'), action: 'openFindingsDashboard' },
    { icon: '📦', label: l10n('welcome.discover.packages.label'), description: l10n('welcome.discover.packages.description'), action: 'openPackageDashboard' },
    { icon: '🎛️', label: l10n('welcome.discover.rules.label'), description: l10n('welcome.discover.rules.description'), action: 'openRulesDashboard' },
    { icon: '📚', label: l10n('welcome.discover.catalog.label'), description: l10n('welcome.discover.catalog.description'), action: 'openCommandCatalog' },
  ];
}

/**
 * Builds the three-card welcome content. Card copy summarizes the v16 upgrade's
 * three highest-impact changes (new LSP diagnostic engine, new machine-health
 * monitoring, and the reshuffled sidebar) — see plans/PLAN_welcome_flow.md for
 * the rationale behind picking exactly these three.
 */
function buildCards(): WelcomeCard[] {
  return [
    {
      icon: '🚨',
      header: l10n('welcome.card.engine.header'),
      body: l10n('welcome.card.engine.body'),
      why: l10n('welcome.card.engine.why'),
      actions: [
        { label: l10n('welcome.card.engine.actionHealth'), action: 'openHealthPanel' },
        { label: l10n('welcome.card.engine.actionRevert'), action: 'revertToAnalyzer' },
      ],
      critical: true,
    },
    {
      icon: '📊',
      header: l10n('welcome.card.monitoring.header'),
      body: l10n('welcome.card.monitoring.body'),
      why: l10n('welcome.card.monitoring.why'),
      actions: [
        { label: l10n('welcome.card.monitoring.actionDashboard'), action: 'openMachineDashboard' },
        { label: l10n('welcome.card.monitoring.actionThresholds'), action: 'openThresholdSettings' },
      ],
      tone: 'accent-info',
    },
    {
      icon: '🧭',
      header: l10n('welcome.card.sidebar.header'),
      body: l10n('welcome.card.sidebar.body'),
      why: l10n('welcome.card.sidebar.why'),
      actions: [
        { label: l10n('welcome.card.sidebar.actionCatalog'), action: 'openCommandCatalog' },
        { label: l10n('welcome.card.sidebar.actionWalkthrough'), action: 'openWalkthrough' },
      ],
      tone: 'accent-medium',
    },
  ];
}

function buildCardHtml(card: WelcomeCard): string {
  const actionsHtml = card.actions
    .map(
      (a, i) =>
        `<button type="button" class="btn${i === 0 ? ' tier-1' : ''}" data-action="${escapeHtml(a.action)}">${escapeHtml(a.label)}</button>`,
    )
    .join('');
  const cardClass = card.critical ? 'welcome-card welcome-card-critical' : 'welcome-card';
  const styleAttr = !card.critical && card.tone ? ` style="border-left-color: var(--${escapeHtml(card.tone)})"` : '';
  return `<section class="${cardClass}"${styleAttr}>
    <h2><span aria-hidden="true">${card.icon}</span> ${escapeHtml(card.header)}</h2>
    <p>${escapeHtml(card.body)}</p>
    <p class="welcome-why">${escapeHtml(card.why)}</p>
    <div class="welcome-actions">${actionsHtml}</div>
  </section>`;
}

/** Colorful 5-tile number showcase — the "show off" band directly under the hero. */
function buildStatsStripHtml(stats: WelcomeStat[]): string {
  const tiles = stats
    .map(
      (s) => `<div class="welcome-stat-tile" style="--stat-tone: var(--${escapeHtml(s.tone)})">
        <span class="welcome-stat-value">${escapeHtml(s.value)}</span>
        <span class="welcome-stat-label">${escapeHtml(s.label)}</span>
      </div>`,
    )
    .join('');
  return `<div class="welcome-stats-strip">${tiles}</div>`;
}

/** Grid of direct links into the other dashboards — separate from the upgrade cards
 * above, which are specific to what changed in this release. */
function buildDiscoveryGridHtml(): string {
  const tiles = buildDiscoveryTiles()
    .map(
      (t) => `<button type="button" class="welcome-discover-tile" data-action="${escapeHtml(t.action)}">
        <span class="welcome-discover-icon" aria-hidden="true">${t.icon}</span>
        <span class="welcome-discover-label">${escapeHtml(t.label)}</span>
        <span class="welcome-discover-description">${escapeHtml(t.description)}</span>
      </button>`,
    )
    .join('');
  return `<section class="welcome-discover">
    <h2>${escapeHtml(l10n('welcome.discover.header'))}</h2>
    <div class="welcome-discover-grid">${tiles}</div>
  </section>`;
}

/**
 * The "keep showing this" checkbox. Starts checked (default behavior: reappear on
 * every activation) and disabled (the user cannot opt out) — it only becomes
 * interactive once the client script detects the panel has been scrolled to the
 * bottom, so a user cannot silently suppress this notice before reading the
 * engine-change card. Wired by welcomePanel-script.ts's scroll listener.
 */
function buildShowNextTimeFooter(): string {
  const enabledHint = escapeHtml(l10n('welcome.checkbox.hintEnabled'));
  return `<div class="welcome-checkbox-row">
    <label>
      <input type="checkbox" id="showNextTime" checked disabled>
      ${escapeHtml(l10n('welcome.checkbox.label'))}
    </label>
    <p class="welcome-checkbox-hint" id="showNextTimeHint" data-enabled-text="${enabledHint}">${escapeHtml(l10n('welcome.checkbox.hint'))}</p>
  </div>`;
}

export function buildWelcomePanelHtml(version: string, ruleCounts: RuleCountSummary | null = null): string {
  const nonce = createWebviewCspNonce();
  const title = l10n('welcome.panel.title');
  const heroHtml = buildDashboardHero({
    title: title.replace(/^Saropa\s+/, ''),
    version,
    showFullWidthToggle: false,
  });
  const cardsHtml = buildCards().map(buildCardHtml).join('\n');
  const statsHtml = buildStatsStripHtml(buildWelcomeStats(ruleCounts));
  const discoveryHtml = buildDiscoveryGridHtml();

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy"
    content="default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(title)}</title>
  <style nonce="${nonce}">${getDashboardChromeStyles()}${getWelcomePanelStyles()}</style>
</head>
<body>
  <header>${heroHtml}</header>
  <main id="welcome-body" tabindex="-1">
    <p class="welcome-subtitle">${escapeHtml(l10n('welcome.hero.subtitle'))}</p>
    ${statsHtml}
    ${cardsHtml}
    ${discoveryHtml}
    ${buildShowNextTimeFooter()}
  </main>
  <script nonce="${nonce}">${getWelcomePanelScript()}</script>
</body>
</html>`;
}
