/**
 * "Saropa Dashboards" — the Home hub. One editor tab giving an at-a-glance answer to "is the
 * project healthy, and where do I go next" (plan `PLAN_extension_ui_redesign.md`, Phase 3 / §2.2).
 *
 * Two bands, six cards:
 *   - **KPI band** ([buildKpiBand] in `dashboardSummaries.ts`) — 6 tiles: health score, open issue
 *     count, diagnostic-engine status, package status, Code Health grade, project size. Replaces
 *     the retired "Saropa Lints" consolidated dashboard's grade-gauge hero (that view showed the
 *     same "how healthy is this project" fact as one gauge; the KPI band tells the fuller story
 *     without needing a second dashboard to hold it).
 *   - **Dashboard cards** — one per other first-class dashboard (Findings, Rules & Tiers, Packages,
 *     Code Health, Project Map, Full Audit), each showing that dashboard's top live signals plus an
 *     "Open" deep-link.
 *
 * **Why nothing here spawns a scan.** Project Map and Code Health are `dart run` dashboards; an
 * earlier version of this hub fully embedded their interactive markup, which meant opening Home
 * always ran two full-project scans sequentially before the page was usable. Every builder this
 * file calls (via `dashboardSummaries.ts`) reads only local files or in-memory caches, so Home
 * always renders instantly — the two heavy dashboards' cards show their last known result (or an
 * honest "not scanned" state) and link out to the real dashboard for a fresh scan.
 */
import * as vscode from 'vscode';
import { getProjectRoot } from '../projectRoot';
import { hasSaropaLintsDep } from '../pubspecReader';
import { l10n } from '../i18n/runtime';
import { formatLanguageChoiceLabel } from '../i18n/languagePick';
import { buildDashboardHero } from './dashboardHero';
import {
  buildCodeHealthSummary,
  buildConfigSummary,
  buildFindingsSummary,
  buildFullAuditSummary,
  buildKpiBand,
  buildPackageSummary,
  buildProjectMapSummary,
  readHomeKpis,
  SUMMARY_OPEN_COMMANDS,
  type HomeKpis,
} from './dashboardSummaries';

let panel: vscode.WebviewPanel | undefined;
let inflight: Promise<void> | undefined;

/**
 * Commands a Home card's "Open" button or the controls band may execute. The webview can only
 * post a `data-command` from this set, so a compromised/buggy script cannot drive arbitrary VS
 * Code commands.
 */
const OPEN_COMMAND_ALLOWLIST: ReadonlySet<string> = new Set<string>([
  SUMMARY_OPEN_COMMANDS.lintsConfig,
  SUMMARY_OPEN_COMMANDS.package,
  SUMMARY_OPEN_COMMANDS.findings,
  SUMMARY_OPEN_COMMANDS.codeHealth,
  SUMMARY_OPEN_COMMANDS.projectMap,
  SUMMARY_OPEN_COMMANDS.fullAudit,
  // Controls band — Actions / Settings / Help. The hub surfaces the full
  // sidebar command set so it is a complete entry point, not just a
  // dashboard-of-dashboards. The webview can only post a command from this
  // set, so a buggy/compromised script cannot drive arbitrary VS Code commands.
  'saropaLints.runAnalysis',
  'saropaLints.initializeConfig',
  'saropaLints.enable',
  'saropaLints.disable',
  'saropaLints.toggleRunAnalysisAfterConfigChange',
  'saropaLints.toggleRunAnalysisAfterDependencyChange',
  'saropaLints.pickUiLanguage',
  'saropaLints.openWalkthrough',
  'saropaLints.showAbout',
  'saropaLints.openPubDevSaropaLints',
  'saropaLints.createSaropaInstructions',
]);

/**
 * Control commands whose effect changes the Settings rows' displayed state
 * (lint integration on/off, run-after toggles, UI language). After executing
 * one, the host recomputes the band and posts `controlsUpdated` so the label
 * reflects the new value without a full re-render.
 */
const CONTROL_STATE_COMMANDS: ReadonlySet<string> = new Set<string>([
  'saropaLints.enable',
  'saropaLints.disable',
  'saropaLints.toggleRunAnalysisAfterConfigChange',
  'saropaLints.toggleRunAnalysisAfterDependencyChange',
  'saropaLints.pickUiLanguage',
]);

/** Registers the `Saropa Dashboards` command; call once at activation. */
export function registerSaropaDashboardsCommand(context: vscode.ExtensionContext): void {
  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.openDashboards', () => openDashboards()),
  );
}

function openDashboards(): Promise<void> {
  if (inflight) {
    panel?.reveal(vscode.ViewColumn.One);
    return inflight;
  }
  const root = getProjectRoot();
  if (!root) {
    void vscode.window.showErrorMessage(l10n('notify.commands.projectMapNoProject'));
    return Promise.resolve();
  }
  if (!hasSaropaLintsDep(root)) {
    void vscode.window.showErrorMessage(l10n('notify.commands.projectMapMissingDep'));
    return Promise.resolve();
  }
  inflight = renderAndLoad(root).finally(() => {
    inflight = undefined;
  });
  return inflight;
}

/**
 * Builds and sets the whole document in one shot. Every input is a cheap read (config, a JSON
 * export, an in-memory cache, a file stat) — no `dart run` scan runs on Home's behalf, so this
 * resolves effectively synchronously and the tab never shows a loading state.
 */
async function renderAndLoad(root: string): Promise<void> {
  const p = getOrCreatePanel();
  p.webview.html = buildShell(
    p.webview.cspSource,
    readHomeKpis(root),
    {
      findings: buildFindingsSummary(root, 3),
      rulesAndTiers: buildConfigSummary(root, 3),
      packages: buildPackageSummary(3),
      codeHealth: buildCodeHealthSummary(3),
      projectMap: buildProjectMapSummary(root, 3),
      fullAudit: buildFullAuditSummary(),
    },
    readControlsState(),
  );
  p.reveal(vscode.ViewColumn.One);
  return Promise.resolve();
}

function getOrCreatePanel(): vscode.WebviewPanel {
  if (panel) return panel;
  panel = vscode.window.createWebviewPanel(
    'saropaDashboards',
    'Saropa Dashboards',
    vscode.ViewColumn.One,
    { enableScripts: true, retainContextWhenHidden: true },
  );
  panel.onDidDispose(() => {
    panel = undefined;
  });
  panel.webview.onDidReceiveMessage((msg: unknown) => handleHostMessage(msg));
  return panel;
}

/** Routes messages from the hub client: allowlisted command deep-links only. */
function handleHostMessage(msg: unknown): void {
  const data = msg as { type?: string; command?: string };
  if (data.type === 'openCommand' && typeof data.command === 'string' && OPEN_COMMAND_ALLOWLIST.has(data.command)) {
    void runControlCommand(data.command);
  }
}

/**
 * Executes an allowlisted control command, then — for the stateful Settings
 * toggles — recomputes the controls band and patches it in place so the row's
 * label shows the new value without a full re-render.
 */
async function runControlCommand(command: string): Promise<void> {
  await vscode.commands.executeCommand(command);
  if (CONTROL_STATE_COMMANDS.has(command) && panel) {
    void panel.webview.postMessage({
      type: 'controlsUpdated',
      html: buildControlsBand(readControlsState()),
    });
  }
}

/** Reads the live config backing the hub's Settings controls. */
function readControlsState(): ControlsState {
  const cfg = vscode.workspace.getConfiguration('saropaLints');
  return {
    lintEnabled: cfg.get<boolean>('enabled', true) ?? true,
    tier: cfg.get<string>('tier', 'recommended') ?? 'recommended',
    runAfterConfig: cfg.get<boolean>('runAnalysisAfterConfigChange', true) ?? true,
    runAfterDependency: cfg.get<boolean>('runAnalysisAfterDependencyChange', true) ?? true,
    uiLanguageLabel: formatLanguageChoiceLabel(cfg.get<string>('uiLanguage', 'auto') ?? 'auto'),
  };
}

/** Pre-built card bodies for the six dashboard cards. Each already carries its own empty state. */
export interface HomeCardSummaries {
  findings: string;
  rulesAndTiers: string;
  packages: string;
  codeHealth: string;
  projectMap: string;
  fullAudit: string;
}

/**
 * Live config backing the hub's Settings controls. Plain data so [buildShell] / [buildControlsBand]
 * stay pure and unit-testable; the host fills it from `saropaLints.*` configuration via
 * [readControlsState].
 */
export interface ControlsState {
  lintEnabled: boolean;
  tier: string;
  runAfterConfig: boolean;
  runAfterDependency: boolean;
  uiLanguageLabel: string;
}

/** Default control state for tests / callers that do not pass live config. */
const DEFAULT_CONTROLS_STATE: ControlsState = {
  lintEnabled: true,
  tier: 'recommended',
  runAfterConfig: true,
  runAfterDependency: true,
  uiLanguageLabel: 'English',
};

/**
 * Builds the full Home hub document, set once as the webview HTML. Pure (no webview): the only
 * host value is [cspSource], so unit tests can assert the shell contract — the KPI band, all six
 * cards, and the controls band — directly.
 */
export function buildShell(
  cspSource: string,
  kpis: HomeKpis,
  cards: HomeCardSummaries,
  controls: ControlsState = DEFAULT_CONTROLS_STATE,
): string {
  const hero = buildDashboardHero({
    title: l10n('dashboards.heroTitle'),
    showFullWidthToggle: false,
  });

  const grid =
    dashboardCard('findings', l10n('dashboards.pane.findings'), SUMMARY_OPEN_COMMANDS.findings, cards.findings) +
    dashboardCard('lintsConfig', l10n('dashboards.pane.lintsConfig'), SUMMARY_OPEN_COMMANDS.lintsConfig, cards.rulesAndTiers) +
    dashboardCard('package', l10n('dashboards.pane.package'), SUMMARY_OPEN_COMMANDS.package, cards.packages) +
    dashboardCard('codeHealth', l10n('dashboards.pane.codeHealth'), SUMMARY_OPEN_COMMANDS.codeHealth, cards.codeHealth) +
    dashboardCard('projectMap', l10n('dashboards.pane.projectMap'), SUMMARY_OPEN_COMMANDS.projectMap, cards.projectMap) +
    dashboardCard('fullAudit', l10n('dashboards.pane.fullAudit'), SUMMARY_OPEN_COMMANDS.fullAudit, cards.fullAudit);

  // 'unsafe-inline' (scripts): the one host shim script runs inline; no nonce needed since there
  // is only ever one script tag. 'unsafe-inline' (styles): the summary metric tone classes are the
  // only per-value styling and are all static class names, but the shared style block itself is
  // inlined the same way every other dashboard in this codebase inlines its `<style>`.
  const csp =
    `default-src 'none'; img-src ${cspSource} data:; ` +
    `style-src ${cspSource} 'unsafe-inline'; script-src ${cspSource} 'unsafe-inline';`;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy" content="${csp}">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Saropa Dashboards</title>
  <style>${hostStyles()}</style>
</head>
<body>
  <header>${hero}</header>
  ${buildKpiBand(kpis)}
  ${buildControlsBand(controls)}
  <main class="dash-grid">${grid}</main>
  <script>${clientScript()}</script>
</body>
</html>`;
}

/** One dashboard card: a titled card with an "Open" deep-link and the card's top signals. */
function dashboardCard(id: string, title: string, command: string, body: string): string {
  const openBtn =
    `<button type="button" class="btn btn-sm" data-command="${escapeHtml(command)}">` +
    `${escapeHtml(l10n('dashboards.card.open'))}</button>`;
  return `<section class="dash-pane">
    <div class="pane-head"><h2>${escapeHtml(title)}</h2><div class="pane-actions">${openBtn}</div></div>
    <div class="pane-body" id="paneBody-${escapeHtml(id)}">${body}</div>
  </section>`;
}

/**
 * The Actions / Settings / Help control band rendered under the KPI band. Pure
 * (state in → HTML out). Buttons carry their command in `data-command`; the
 * client delegates clicks to the host, which runs the (allowlisted) command.
 * Settings buttons show the current value in their label and re-render via a
 * `controlsUpdated` message after a toggle. The container id lets the client
 * patch just this band without a full re-render.
 */
export function buildControlsBand(state: ControlsState): string {
  const onOff = (on: boolean): string =>
    on ? l10n('dashboards.controls.on') : l10n('dashboards.controls.off');
  const yesNo = (yes: boolean): string =>
    yes ? l10n('dashboards.controls.yes') : l10n('dashboards.controls.no');

  const actions =
    controlBtn('saropaLints.runAnalysis', l10n('dashboards.controls.runAnalysis')) +
    controlBtn('saropaLints.initializeConfig', l10n('dashboards.controls.initializeConfig'));

  // The lint-integration button toggles, so its command flips with current state.
  const settings =
    controlBtn(
      state.lintEnabled ? 'saropaLints.disable' : 'saropaLints.enable',
      l10n('dashboards.controls.lintIntegrationState', { state: onOff(state.lintEnabled) }),
    ) +
    controlBtn(
      'saropaLints.openConfigDashboard',
      l10n('dashboards.controls.tierState', { tier: state.tier }),
    ) +
    controlBtn(
      'saropaLints.toggleRunAnalysisAfterConfigChange',
      l10n('dashboards.controls.runAfterConfigState', { state: yesNo(state.runAfterConfig) }),
    ) +
    controlBtn(
      'saropaLints.toggleRunAnalysisAfterDependencyChange',
      l10n('dashboards.controls.runAfterDependencyState', { state: yesNo(state.runAfterDependency) }),
    ) +
    controlBtn(
      'saropaLints.pickUiLanguage',
      l10n('dashboards.controls.uiLanguageState', { language: state.uiLanguageLabel }),
    );

  const help =
    controlBtn('saropaLints.openWalkthrough', l10n('dashboards.controls.gettingStarted')) +
    controlBtn('saropaLints.showAbout', l10n('dashboards.controls.about')) +
    controlBtn('saropaLints.openPubDevSaropaLints', l10n('dashboards.controls.pubDev')) +
    controlBtn('saropaLints.createSaropaInstructions', l10n('dashboards.controls.aiInstructions'));

  return `<div id="dashControls" class="dash-controls">
    ${controlGroup(l10n('dashboards.controls.actions'), actions)}
    ${controlGroup(l10n('dashboards.controls.settings'), settings)}
    ${controlGroup(l10n('dashboards.controls.help'), help)}
  </div>`;
}

/** One titled group of control buttons in the band. */
function controlGroup(title: string, buttons: string): string {
  return `<section class="ctl-group">
    <h2 class="ctl-title">${escapeHtml(title)}</h2>
    <div class="ctl-buttons">${buttons}</div>
  </section>`;
}

/** One control button. The full label is escaped — it may carry a config value. */
function controlBtn(command: string, label: string): string {
  return `<button type="button" class="btn ctl-btn" data-command="${escapeHtml(command)}">${escapeHtml(label)}</button>`;
}

/** Host layout: the KPI band, responsive card grid, and summary-metric styling on shared tokens. */
function hostStyles(): string {
  return `
.kpi-band {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: var(--space-3, 12px);
  margin-bottom: var(--space-4, 16px);
}
.kpi-tile .metric-value { font-size: 1.7rem; }
.dash-controls {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-4, 16px);
  margin-bottom: var(--space-4, 16px);
}
.ctl-group {
  display: flex;
  flex-direction: column;
  gap: var(--space-2, 8px);
  flex: 1 1 240px;
  min-width: 0;
  padding: var(--space-3, 12px);
  border: 1px solid var(--border, var(--vscode-widget-border));
  border-radius: var(--radius-lg, 12px);
  background: var(--surface-1, var(--vscode-editorWidget-background));
}
.ctl-title {
  margin: 0;
  font-size: var(--text-h3, 1.05rem);
  color: var(--muted, var(--vscode-descriptionForeground));
}
.ctl-buttons { display: flex; flex-wrap: wrap; gap: var(--space-2, 8px); }
.ctl-btn { white-space: nowrap; }
.dash-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
  gap: var(--space-4, 16px);
  align-items: start;
}
.dash-pane {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--border, var(--vscode-widget-border));
  border-radius: var(--radius-lg, 12px);
  background: var(--surface-1, var(--vscode-editorWidget-background));
  overflow: hidden;
  min-width: 0;
}
.pane-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-2, 8px);
  padding: var(--space-2, 8px) var(--space-3, 12px);
  border-bottom: 1px solid var(--border, var(--vscode-widget-border));
  background: var(--surface-2, var(--vscode-editor-inactiveSelectionBackground));
}
.pane-head h2 { margin: 0; font-size: var(--text-h3, 1.05rem); }
.pane-actions { display: flex; align-items: center; gap: var(--space-2, 8px); }
.btn-sm { padding: 2px 10px; font-size: 0.85rem; }
.pane-body { padding: var(--space-3, 12px); min-width: 0; overflow-x: auto; }
.summary-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(110px, 1fr));
  gap: var(--space-3, 12px);
}
.metric {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: var(--space-3, 12px);
  border: 1px solid var(--border, var(--vscode-widget-border));
  border-radius: var(--radius-md, 8px);
  /* --surface-1 (editorWidget-background), not --surface-2 (inactiveSelectionBackground): the
     Phase 7 UX-harness sweep measured .metric-label's muted text at 4.02:1 against surface-2,
     under the 4.5:1 AA floor. Selection-highlight surfaces are tuned to sit close to muted text by
     design (a selection tint deliberately doesn't fight the description-foreground color it was
     drawn behind); a static card background needs the wider margin editorWidget-background gives. */
  background: var(--surface-1, var(--vscode-editorWidget-background));
}
.metric-value { font-size: 1.5rem; font-weight: 600; font-variant-numeric: tabular-nums; line-height: 1.1; }
.metric-label { font-size: 0.8rem; color: var(--muted, var(--vscode-descriptionForeground)); }
/* A left-border accent, not a recolored value: the Phase 7 UX-harness sweep measured
   --accent-warning (editorWarning-foreground, a yellow/amber tuned for small icons on the editor
   background) at 2.93:1 against this card's surface in the light theme -- badly under the 4.5:1 AA
   floor for 1.5rem body text. Warning/amber and error/red tones are reliable for a THIN accent
   stripe or an icon at any size, but not guaranteed-readable as full-size text color across every
   shipped theme; the value stays at full-contrast foreground and the tone is carried by the border
   instead, so the KPI's "this needs attention" signal survives without gambling on contrast. */
.metric-warn { border-left: 3px solid var(--accent-warning, var(--vscode-editorWarning-foreground)); }
.metric-bad { border-left: 3px solid var(--accent-error, var(--vscode-errorForeground)); }
.summary-empty { color: var(--muted, var(--vscode-descriptionForeground)); margin: 0; padding: var(--space-3, 12px) 0; }
`;
}

/**
 * The single client script: delegates deep-link clicks to the host, and patches the controls band
 * in place after a settings toggle. Home no longer embeds any heavy dashboard, so there is no
 * `acquireVsCodeApi` sharing, pane streaming, or style injection to manage — this is one small
 * always-static script.
 */
function clientScript(): string {
  return `
(function () {
  var api = acquireVsCodeApi();

  document.addEventListener('click', function (e) {
    var openEl = e.target.closest && e.target.closest('[data-command]');
    if (openEl) { api.postMessage({ type: 'openCommand', command: openEl.getAttribute('data-command') }); }
  });

  window.addEventListener('message', function (e) {
    var m = e.data || {};
    // Patch only the controls band after a settings toggle — the html is host-built
    // and escaped, and click handling is delegated on document so it survives the swap.
    if (m.type === 'controlsUpdated') {
      var ctl = document.getElementById('dashControls');
      if (ctl && typeof m.html === 'string') { ctl.outerHTML = m.html; }
    }
  });
})();
`;
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
